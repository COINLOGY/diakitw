class Sampler {
 constructor(collect,publish,interval=2000){Object.assign(this,{collect,publish,interval,active:false,busy:false,generation:0});}
 start(){if(this.active)return;this.active=true;this.generation++;this.tick();}
 async tick(){if(!this.active||this.busy)return;this.busy=true;const g=this.generation;this.controller=new AbortController();try{const data=await this.collect(this.controller.signal);if(this.active&&g===this.generation)this.publish(data);}catch{}finally{this.busy=false;if(this.active)this.timer=setTimeout(()=>this.tick(),this.interval);}}
 stop(){this.active=false;this.generation++;clearTimeout(this.timer);this.controller?.abort();}
}
function validSender(event,wc){return !!wc&&event.sender===wc&&event.senderFrame===wc.mainFrame&&event.senderFrame.url==='diakitw://app/index.html';}
function selectInterface(name,names){return typeof name==='string'&&name.length<=256&&names.includes(name)?name:null;}
function allowedRequest(url,assets){return typeof url==='string'&&assets.has(url);}
module.exports={Sampler,validSender,selectInterface,allowedRequest};
