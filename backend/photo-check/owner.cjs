const path=require('node:path');
const {execFileSync}=require('node:child_process');
function firebaseOwnerAuth(){
  try{return require('firebase-tools/lib/auth.js');}catch{
    const root=process.env.APPDATA?path.join(process.env.APPDATA,'npm/node_modules'):execFileSync('npm',['root','-g'],{encoding:'utf8'}).trim();
    return require(path.join(root,'firebase-tools/lib/auth.js'));
  }
}
module.exports={firebaseOwnerAuth};
