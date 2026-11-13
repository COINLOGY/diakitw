import unittest
import tempfile
import pathlib
import sqlite3
import service

class MonthlyTests(unittest.TestCase):
    def test_month_limit_independent_of_day(self):
        with tempfile.TemporaryDirectory() as d:
            path=str(pathlib.Path(d)/'q')
            service.Quota.initialize(path)
            with sqlite3.connect(path) as db:
                db.execute('INSERT INTO usage VALUES (?,?)',('m:2027-01',8999))
            service.Quota(path).reserve(1798761600)
            with self.assertRaises(service.SafeError):
                service.Quota(path).reserve(1798761600+86400)
            with sqlite3.connect(path) as db:
                self.assertEqual(db.execute('SELECT count FROM usage WHERE period=?',('m:2027-01',)).fetchone()[0],9000)
                self.assertIsNone(db.execute('SELECT count FROM usage WHERE period=?',('d:2027-01-02',)).fetchone())
