const express=require('express');
const fs=require('fs');
const path=require('path');
const app=express();
app.use(express.json());
app.use(express.static(path.join(__dirname,'build')));

const DB_FILE=path.join(__dirname,'dot-cells.json');

function loadDB(){
  try{return JSON.parse(fs.readFileSync(DB_FILE,'utf8'));}
  catch(e){return {};}
}
function saveDB(data){
  fs.writeFileSync(DB_FILE,JSON.stringify(data,null,2));
}

// 전체 칸 조회
app.get('/dot-api/cells',(req,res)=>{
  res.json(loadDB());
});

// 칸 입주/업데이트
app.post('/dot-api/cells/:id',(req,res)=>{
  const db=loadDB();
  const id=req.params.id.toUpperCase();
  db[id]={...db[id],...req.body,updatedAt:new Date().toISOString()};
  saveDB(db);

  // 해당 칸 HTML 자동 생성
  const cell=db[id];
  const html=generateHTML(id,cell);
  const filePath=path.join(__dirname,'build','dot',id+'.html');
  fs.mkdirSync(path.dirname(filePath),{recursive:true});
  fs.writeFileSync(filePath,html);

  res.json({ok:true,cell:db[id]});
});

// 칸 조회
app.get('/dot-api/cells/:id',(req,res)=>{
  const db=loadDB();
  const id=req.params.id.toUpperCase();
  res.json(db[id]||{});
});

function generateHTML(id,cell){
  const typeColors={office:'#378add',shop:'#F5A623',game:'#27AE60',meet:'#7B68EE',nft:'#E23B3B',social:'#1ABC9C'};
  const typeNames={office:'사무실',shop:'Dot 상점',game:'게임룸',meet:'미팅룸',nft:'NFT/AU',social:'소셜'};
  const color=typeColors[cell.type]||'#F5A623';
  const typeName=typeNames[cell.type]||'공간';

  return `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${cell.name||id} — Dot Metaverse</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#020818;color:#fff;font-family:sans-serif;min-height:100vh}
.top{background:#0a0a1a;padding:10px 16px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid ${color}33}
.logo{color:${color};font-weight:700;font-size:15px}
.addr{font-size:11px;color:rgba(255,255,255,0.3);font-family:monospace}
.hero{padding:40px 24px;border-bottom:1px solid rgba(255,255,255,0.06)}
.cell-id{font-size:48px;font-weight:700;color:${color}22;letter-spacing:0.1em;margin-bottom:8px}
.cell-name{font-size:28px;font-weight:500;color:#fff;margin-bottom:6px}
.cell-type{font-size:13px;color:${color};margin-bottom:16px}
.cell-desc{font-size:14px;color:rgba(255,255,255,0.5);line-height:1.7;max-width:600px}
.content{padding:24px}
.owner-card{background:rgba(255,255,255,0.04);border:1px solid ${color}33;border-radius:12px;padding:16px 20px;margin-bottom:16px}
.oc-label{font-size:11px;color:rgba(255,255,255,0.35);margin-bottom:6px}
.oc-val{font-size:15px;font-weight:500;color:${color}}
.back-btn{display:inline-block;margin-top:20px;padding:8px 20px;border:1px solid ${color};border-radius:8px;color:${color};font-size:13px;text-decoration:none}
.edit-btn{display:inline-block;margin-top:20px;margin-left:10px;padding:8px 20px;background:${color}22;border:1px solid ${color};border-radius:8px;color:${color};font-size:13px;cursor:pointer}
</style>
</head>
<body>
<div class="top">
  <div class="logo">⬡ Dot · ${id}</div>
  <div class="addr">https://tobmate.com/dot/${id}.html</div>
</div>
<div class="hero">
  <div class="cell-id">${id}</div>
  <div class="cell-name">${cell.name||id+' 공간'}</div>
  <div class="cell-type">${typeName} · Layer ${cell.layer||1}</div>
  <div class="cell-desc">${cell.desc||'이 공간을 꾸며보세요.'}</div>
</div>
<div class="content">
  <div class="owner-card">
    <div class="oc-label">소유자</div>
    <div class="oc-val">${cell.owner||'미분양'}</div>
  </div>
  <div class="owner-card">
    <div class="oc-label">연락처 / 링크</div>
    <div class="oc-val">${cell.link||'-'}</div>
  </div>
  <a class="back-btn" href="/dot.html">← 전체 지도</a>
  <span class="edit-btn" onclick="location.href='/dot-admin.html?cell=${id}'">편집 ✏</span>
</div>
</body>
</html>`;
}

const PORT=3333;
app.listen(PORT,()=>console.log('Dot Admin 서버 포트:'+PORT));

// AU 요금 설정
const PRICING={
  deposit:10,      // 입주 보증금 (AU)
  monthly:2,       // 월세 (AU)
  commission:0.03, // 거래 수수료 3%
  layer1:10,       // L1 분양가
  layer2:20,       // L2 분양가
  layer3:50,       // L3 분양가
};

// 분양 신청 (AU 결제 포함)
app.post('/dot-api/purchase',(req,res)=>{
  const db=loadDB();
  const {cellId,userId,name,type,desc,link,layer,auAmount}=req.body;
  if(!cellId||!userId){return res.json({ok:false,msg:'필수값 누락'});}
  if(db[cellId]&&db[cellId].status==='approved'){
    return res.json({ok:false,msg:'이미 분양된 칸입니다'});}
  const lyr=layer||1;
  const required=lyr===1?PRICING.layer1:lyr===2?PRICING.layer2:PRICING.layer3;
  if(auAmount<required){
    return res.json({ok:false,msg:'AU 부족. 필요: '+required+' AU'});}
  db[cellId]=db[cellId]||{};
  Object.assign(db[cellId],{
    cellId,userId,name,type,desc,link,
    layer:lyr,auPaid:auAmount,
    status:'pending',
    appliedAt:new Date().toISOString(),
    pricing:{deposit:required,monthly:PRICING.monthly,commission:PRICING.commission}
  });
  saveDB(db);
  res.json({ok:true,msg:'신청완료! AU '+auAmount+' 납부확인. 관리자 승인 대기중',pricing:PRICING});
});

// 거래 수수료 정산
app.post('/dot-api/trade',(req,res)=>{
  const db=loadDB();
  const {cellId,userId,amount,item}=req.body;
  const cell=db[cellId];
  if(!cell||cell.status!=='approved'){
    return res.json({ok:false,msg:'분양되지 않은 칸'});}
  const fee=Math.round(amount*PRICING.commission*100)/100;
  const net=amount-fee;
  if(!cell.trades)cell.trades=[];
  cell.trades.push({userId,amount,fee,net,item,date:new Date().toISOString()});
  cell.totalRevenue=(cell.totalRevenue||0)+net;
  cell.totalFee=(cell.totalFee||0)+fee;
  saveDB(db);
  res.json({ok:true,amount,fee,net,msg:'거래완료. 수수료: '+fee+' AU'});
});

// 수익 조회
app.get('/dot-api/revenue/:cellId',(req,res)=>{
  const db=loadDB();
  const cell=db[req.params.cellId.toUpperCase()];
  if(!cell)return res.json({ok:false,msg:'없음'});
  res.json({
    ok:true,cellId:req.params.cellId,
    owner:cell.owner,
    totalRevenue:cell.totalRevenue||0,
    totalFee:cell.totalFee||0,
    trades:cell.trades||[],
    pricing:cell.pricing||PRICING
  });
});

// 요금 조회
app.get('/dot-api/pricing',(req,res)=>{res.json(PRICING);});
