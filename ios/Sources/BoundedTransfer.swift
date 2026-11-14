import Foundation

/// One request, no redirects/retries/cookies/cache; finite deadline and retained-body cap.
/// Transport buffering and protocol overhead are not an exact on-wire byte quota.
final class BoundedTransfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var session: URLSession?
    private var continuation: CheckedContinuation<Data, Error>?
    private var cancelled = false
    private var body = Data()
    private let cap: Int
    private init(cap: Int) { self.cap = cap }

    static func fetch(_ request: URLRequest, cap: Int,
                      configuration: URLSessionConfiguration = .ephemeral) async throws -> Data {
        guard request.url?.scheme == "https", cap > 0 else { throw URLError(.unsupportedURL) }
        let transfer = BoundedTransfer(cap: cap)
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                transfer.start(request, configuration: configuration, continuation: continuation)
            }
        }, onCancel: { transfer.cancel() })
    }
    private func start(_ request: URLRequest, configuration: URLSessionConfiguration,
                       continuation: CheckedContinuation<Data, Error>) {
        lock.lock()
        guard !cancelled else { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
        self.continuation = continuation
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        self.session = session
        let task = session.dataTask(with: request)
        task.resume()
        lock.unlock()
        // Independent wall-clock deadline, including a stalled server/delegate.
        DispatchQueue.global().asyncAfter(deadline: .now() + 22) { [weak self] in
            self?.finish(.failure(URLError(.timedOut)))
        }
    }
    private func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
        finish(.failure(CancellationError()))
    }
    private func finish(_ result: Result<Data, Error>) {
        lock.lock()
        let callback = continuation; continuation = nil
        let active = session; session = nil
        lock.unlock()
        active?.invalidateAndCancel()
        callback?.resume(with: result)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
        finish(.failure(URLError(.redirectToNonExistentLocation)))
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              response.expectedContentLength <= Int64(cap) else {
            completionHandler(.cancel); finish(.failure(URLError(.badServerResponse))); return
        }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard data.count <= cap - body.count else {
            finish(.failure(URLError(.dataLengthExceedsMaximum))); return
        }
        body.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) } else { finish(.success(body)) }
    }
}
