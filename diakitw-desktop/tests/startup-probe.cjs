console.log('ENTRY',process.versions); const {app}=require('electron'); console.log('APP',!!app); app.whenReady().then(()=>{console.log('READY');app.quit()}); setTimeout(()=>app.exit(3),5000);
