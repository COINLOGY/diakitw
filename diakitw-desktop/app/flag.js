// Regional-indicator emoji, only for the country returned with the current egress IP.
function countryFlag(egress){
 const code=egress?.code;
 if(egress?.status!=='current'||!egress.country||typeof code!=='string'||!/^[A-Z]{2}$/.test(code)||['ZZ','EU','UN','XA','XB'].includes(code))return '';
 return String.fromCodePoint(...[...code].map(letter=>127397+letter.charCodeAt(0)));
}
