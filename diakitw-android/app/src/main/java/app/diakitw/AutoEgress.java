package app.diakitw;
/** Main-thread state machine. Elapsed realtime only; transport stays busy until exit. */
final class AutoEgress {
 static final long DEBOUNCE=1500,COOLDOWN=10000,FALLBACK=60000;
 boolean foreground,running;long generation,active=-1,lastStart=-FALLBACK,due=Long.MAX_VALUE,blockedUntil;
 void blockUntil(long time){blockedUntil=Math.max(blockedUntil,time);}
 void resume(long now){foreground=true;generation++;due=Math.max(now+DEBOUNCE,lastStart+COOLDOWN);}
 void changed(long now){if(!foreground)return;generation++;due=Math.max(now+DEBOUNCE,lastStart+COOLDOWN);}
 void pause(){foreground=false;generation++;due=Long.MAX_VALUE;}
 long begin(long now,boolean networkBusy){if(!foreground||running||networkBusy||now<due||now<blockedUntil)return -1;running=true;active=++generation;lastStart=now;due=now+FALLBACK;return active;}
 boolean complete(long token){if(!running||token!=active)return false;running=false;return foreground&&token==generation;}
}
