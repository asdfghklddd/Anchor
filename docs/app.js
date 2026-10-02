'use strict';
(() => {
  const data = window.ANCHOR_MAP;
  const byId = Object.fromEntries(data.pages.map(p => [p.id, p]));
  const $ = s => document.querySelector(s);
  const escape = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  let currentFlow = data.flows[0], platform = 'all', selectedRoute = -1, openedPage = null, previousHash = '#map', lastTrigger = null;
  const tag = p => `<span class="tag ${p.platform}">${p.platform === 'Core' ? '共享核心' : p.platform}</span>`;
  const glyphs = {iPhone:'屏幕 / 页面',Mac:'窗口 / 控件',Core:'状态 / 数据'};
  const schema = p => `<div class="schema-content"><span>${glyphs[p.platform]}</span><div class="schema-line">${escape(p.title)}</div><div class="schema-connector"></div><div class="schema-line muted">${escape(p.behavior[0].slice(0,38))}</div><div class="schema-line muted">${escape(p.kind)} · 查看实现依据 ↗</div></div>`;
  $('#page-count').textContent = data.pages.length;
  $('#map-tabs').innerHTML = data.flows.map((f,i) => `<button data-flow="${f.id}" aria-pressed="${i===0}"><span>0${i+1}</span>${['工作主线','iPhone','离开与返航','Mac','数据与同步'][i]}</button>`).join('');
  $('#platform-tabs').innerHTML = [['all','全部'],['iPhone','iPhone'],['Mac','Mac'],['Core','共享核心']].map(([id,label])=>`<button data-platform="${id}" aria-pressed="${id==='all'}">${label}</button>`).join('');

  function renderFlow(id) {
    currentFlow = data.flows.find(f => f.id === id) || data.flows[0]; selectedRoute = -1;
    document.querySelectorAll('[data-flow]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.flow === currentFlow.id)));
    $('#map-title').textContent = currentFlow.title; $('#map-subtitle').textContent = currentFlow.subtitle;
    const labels = {journey:['01 / 手机建立工作','02 / Mac 观察与同步','03 / 离开、返航与完成'],iphone:['01 / 一级页面','02 / 操作与列表','03 / 详情与设置'],returning:['01 / 工作与信号','02 / 全屏状态切换','03 / 回顾与继续'],mac:['01 / 边缘入口','02 / 侧栏分区','03 / 查看与接入'],system:['01 / 输入与来源','02 / 共享状态与存储','03 / 同步与呈现']};
    $('#map-lanes').innerHTML = currentFlow.columns.map((lane,index)=>`<div class="lane"><div class="lane-label">${labels[currentFlow.id][index]}</div>${lane.map((id,n)=>{const p=byId[id];return `<button class="map-node" data-page="${p.id}" data-node="${p.id}"><span class="node-top">${tag(p)}<span class="node-number">${String(index+1)}.${String(n+1).padStart(2,'0')}</span></span><strong>${escape(p.title)}</strong><p>${escape(p.summary)}</p><span class="node-arrow" aria-hidden="true">↗</span></button>`}).join('')}</div>`).join('');
    $('#route-count').textContent = currentFlow.edges.length + ' 条';
    $('#routes').innerHTML = currentFlow.edges.map(([a,b,label,kind],n)=>`<button class="route-button" data-route="${n}" aria-pressed="false"><strong>${escape(byId[a].title)} → ${escape(byId[b].title)}</strong><small>${kind==='sync'?'↔ ':kind==='auto'?'◷ ':''}${escape(label)}</small></button>`).join('');
    $('#map-status').textContent = '点击一条路径，可高亮起点与终点。';
    $('#map-viewport').scrollTop = 0; $('#map-viewport').scrollLeft = 0;
    requestAnimationFrame(drawLines);
  }
  function drawLines() {
    const canvas = $('#map-canvas'), bounds = canvas.getBoundingClientRect(), svg = $('#map-lines');
    svg.setAttribute('viewBox', `0 0 ${canvas.offsetWidth} ${canvas.offsetHeight}`);
    let paths = '<defs>'+[['tap','#789b84'],['sync','#357a9d'],['auto','#bb7a37']].map(([name,color])=>`<marker id="arrow-${name}" markerWidth="7" markerHeight="7" refX="6" refY="3.5" orient="auto"><path d="M0,0 L7,3.5 L0,7" fill="${color}"/></marker>`).join('')+'</defs>';
    currentFlow.edges.forEach(([a,b,label,kind='tap'],idx)=>{
      const u = canvas.querySelector(`[data-node="${a}"]`), v = canvas.querySelector(`[data-node="${b}"]`);if(!u||!v)return;
      const ur=u.getBoundingClientRect(),vr=v.getBoundingClientRect(), sameColumn=Math.abs(ur.left-vr.left)<10, right=vr.left>ur.left;
      let x1,y1,x2,y2,path;
      if(sameColumn){const down=vr.top>ur.top;x1=ur.left-bounds.left+ur.width/2;x2=vr.left-bounds.left+vr.width/2;y1=(down?ur.bottom:ur.top)-bounds.top;y2=(down?vr.top:vr.bottom)-bounds.top;const mid=(y1+y2)/2;path=`M${x1} ${y1} C${x1} ${mid} ${x2} ${mid} ${x2} ${y2}`;}
      else{x1=(right?ur.right:ur.left)-bounds.left;x2=(right?vr.left:vr.right)-bounds.left;y1=ur.top-bounds.top+ur.height/2;y2=vr.top-bounds.top+vr.height/2;const offset=right?24:-24;path=`M${x1} ${y1} C${x1+offset} ${y1} ${x2-offset} ${y2} ${x2} ${y2}`;}
      const selected=selectedRoute===idx, faded=selectedRoute!==-1&&!selected;
      paths+=`<path d="${path}" fill="none" stroke="${kind==='sync'?'#357a9d':kind==='auto'?'#bb7a37':'#789b84'}" stroke-width="${selected?2.6:1.3}" opacity="${faded?.12:selected?1:.4}" ${kind==='auto'?'stroke-dasharray="5 4"':''} marker-end="url(#arrow-${kind})"/>`;
    });svg.innerHTML=paths;
  }
  function highlightRoute(index) {
    selectedRoute = selectedRoute === index ? -1 : index;
    const edge=currentFlow.edges[selectedRoute];
    document.querySelectorAll('[data-route]').forEach(b=>{const active=Number(b.dataset.route)===selectedRoute;b.classList.toggle('active',active);b.setAttribute('aria-pressed',String(active));});
    document.querySelectorAll('[data-node]').forEach(b=>{const on=edge&&edge.slice(0,2).includes(b.dataset.node);b.classList.toggle('highlight',!!on);b.classList.toggle('dim',!!edge&&!on);});
    $('#map-status').textContent=edge?`${byId[edge[0]].title} → ${byId[edge[1]].title}：${edge[2]}`:'点击一条路径，可高亮起点与终点。';drawLines();
  }
  function renderPages() {
    const term=$('#search').value.trim().toLocaleLowerCase(),onlyScreens=$('#screens-only').checked;
    const results=data.pages.filter(p=>(platform==='all'||p.platform===platform)&&(!onlyScreens||p.image)&&`${p.title} ${p.summary} ${p.entry} ${p.behavior.join(' ')} ${p.platform}`.toLocaleLowerCase().includes(term));
    $('#result-count').textContent=`${results.length} 个结果 / 共 ${data.pages.length} 个页面与模块`;
    $('#empty-state').hidden=results.length!==0;
    $('#page-grid').innerHTML=results.map(p=>`<button class="page-card" data-page="${p.id}"><div class="card-preview ${p.image?(p.platform==='Mac'||p.imageAspect==='wide'?'mac':''):'schema'}">${p.image?`<img src="assets/${p.image}" alt="${escape(p.imageAlt || p.title+'的测试界面')}" loading="lazy" decoding="async">`:schema(p)}</div>${p.imageLabel?`<span class="image-label">${escape(p.imageLabel)}</span>`:''}<div class="card-content"><div class="card-meta">${tag(p)}<small>${escape(p.kind)}</small></div><h3>${escape(p.title)}</h3><p>${escape(p.summary)}</p><span class="card-foot"><span>${p.image?'界面素材 · 2026.10.02':'结构说明 · 源码核对'}</span><span aria-hidden="true">↗</span></span></div></button>`).join('');
  }
  $('#module-grid').innerHTML=data.modules.map(([title,ids],n)=>`<article class="module"><header><h3>${escape(title)}</h3><span>0${n+1} / ${ids.length}</span></header>${ids.map(id=>`<button data-page="${id}">${escape(byId[id].title)}<span>${byId[id].platform==='Core'?'Core':byId[id].platform} ↗</span></button>`).join('')}</article>`).join('');
  const dialog=$('#detail-dialog');
  function openPage(id,updateHash=true) {
    const p=byId[id];if(!p)return;
    if(!dialog.open){lastTrigger=document.activeElement;previousHash=location.hash.startsWith('#page/')?'#pages':location.hash||'#map';}
    openedPage=id;$('#detail-kicker').textContent=`ANCHOR / ${p.platform==='Core'?'共享核心':p.platform} / ${p.kind}`;
    const relations = [...new Set(data.flows.flatMap(f=>f.edges.filter(e=>e[0]===id).map(e=>e[1])))];
    const sourceUrl=`${data.repo}/blob/${data.baseline}/${p.source}`;
    const currentUrl=`${location.href.split('#')[0]}#page/${id}`;
    const issueUrl=data.repo+'/issues/new?'+new URLSearchParams({title:`[地图反馈] ${p.title}`,body:`页面：${p.title}\n地图：${currentUrl}\n源码基线：${data.baseline.slice(0,7)}\n\n观察到的情况：\n\n建议或截图：\n`});
    const evidence=p.image?data.assets?.[p.image]:null;
    $('#detail-content').innerHTML=`<div class="detail-layout"><div class="detail-visual">${p.image?`<img src="assets/${p.image}" alt="${escape(p.imageAlt || p.title+'的当前界面素材')}"><a class="full-image" href="assets/${p.image}" target="_blank" rel="noopener">打开完整截图 ↗</a><small>${escape(evidence?.caption||'2026 年 10 月 2 日 · 原生界面，隔离测试数据。截图仅展示此时的布局和状态。')}</small>`:`<div class="detail-placeholder">${schema(p)}<p>本节点使用当前源码整理的结构说明，未把示意图作为应用实机截图。</p></div>`}</div><div class="detail-body">${tag(p)}<h2 id="detail-title">${escape(p.title)}</h2><p>${escape(p.summary)}</p><h3>从哪里进入</h3><div class="entry">${escape(p.entry)}</div><h3>页面与交互规则</h3><ul>${p.behavior.map(t=>`<li>${escape(t)}</li>`).join('')}</ul>${relations.length?`<h3>接下来可以去</h3><div class="detail-links">${relations.map(id=>`<button data-page="${id}">${escape(byId[id].title)} →</button>`).join('')}</div>`:''}<div class="detail-actions"><button id="copy-page-link">复制页面链接</button><a href="${escape(sourceUrl)}" target="_blank" rel="noopener">查看源码 ↗</a><a href="${escape(issueUrl)}" target="_blank" rel="noopener">在 GitHub 反馈 ↗</a></div>${p.localRevision?'<p class="revision-note">界面素材包含 2026-10-02 本地可读性修订。下方源码链接固定到已提交基线；本地修订的文件校验记录见维护说明。</p>':''}<div class="source-path">${escape(p.source)}<br>源码基线 ${data.baseline.slice(0,7)} · 发布网页不会连接个人任务数据。</div></div></div>`;
    if(!dialog.open)dialog.showModal();
    dialog.scrollTop=0;$('#close-dialog').focus({preventScroll:true});
    if(updateHash)history.replaceState(null,'',`#page/${id}`);
    $('#copy-page-link').addEventListener('click',async()=>{try{await navigator.clipboard.writeText(currentUrl);toast('页面链接已复制');}catch{toast('请复制浏览器地址栏中的页面链接');}});
  }
  function closeDialog(){dialog.close();}
  dialog.addEventListener('close',()=>{openedPage=null;if(location.hash.startsWith('#page/'))history.replaceState(null,'',previousHash);if(lastTrigger?.isConnected)lastTrigger.focus({preventScroll:true});});
  dialog.addEventListener('click',e=>{if(e.target===dialog){const b=dialog.getBoundingClientRect();if(e.clientX<b.left||e.clientX>b.right||e.clientY<b.top||e.clientY>b.bottom)closeDialog();}});
  $('#close-dialog').addEventListener('click',closeDialog);
  function toast(message){$('#toast').textContent=message;$('#toast').classList.add('show');clearTimeout(toast.timer);toast.timer=setTimeout(()=>$('#toast').classList.remove('show'),2600);}
  document.addEventListener('click',e=>{
    const page=e.target.closest('[data-page]');if(page){openPage(page.dataset.page);return;}
    const flow=e.target.closest('[data-flow]');if(flow){renderFlow(flow.dataset.flow);history.replaceState(null,'',`#map/${flow.dataset.flow}`);return;}
    const route=e.target.closest('[data-route]');if(route){highlightRoute(Number(route.dataset.route));return;}
    const filter=e.target.closest('[data-platform]');if(filter){platform=filter.dataset.platform;document.querySelectorAll('[data-platform]').forEach(b=>b.setAttribute('aria-pressed',String(b===filter)));renderPages();}
  });
  $('#clear-route').addEventListener('click',()=>{selectedRoute=-2;highlightRoute(-1);});
  $('#search').addEventListener('input',renderPages);$('#screens-only').addEventListener('change',renderPages);
  $('#reset-search').addEventListener('click',()=>{platform='all';$('#search').value='';$('#screens-only').checked=false;document.querySelectorAll('[data-platform]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.platform==='all')));renderPages();});
  $('#open-system').addEventListener('click',()=>{renderFlow('system');location.hash='map/system';$('#map').scrollIntoView();});
  $('#print').addEventListener('click',()=>window.print());
  document.addEventListener('keydown',e=>{if(e.key==='/'&&!dialog.open&&!['INPUT','TEXTAREA'].includes(document.activeElement.tagName)){e.preventDefault();$('#pages').scrollIntoView();$('#search').focus({preventScroll:true});}});
  function applyHash(){const [type,id]=location.hash.slice(1).split('/');if(type==='page'&&byId[id])openPage(id,false);else{if(dialog.open)dialog.close();if(type==='map'&&id){renderFlow(id);$('#map').scrollIntoView({behavior:'instant'});}}}
  window.addEventListener('hashchange',applyHash);
  new ResizeObserver(()=>requestAnimationFrame(drawLines)).observe($('#map-lanes'));
  const observer=new IntersectionObserver(entries=>{for(const entry of entries){if(entry.isIntersecting){document.querySelectorAll('[data-section]').forEach(a=>a.classList.toggle('active',a.dataset.section===entry.target.id));}}},{rootMargin:'-15% 0px -65% 0px'});document.querySelectorAll('main>.section').forEach(section=>observer.observe(section));
  window.addEventListener('beforeprint',()=>{selectedRoute=-1;drawLines();});window.addEventListener('afterprint',drawLines);
  renderFlow('journey');renderPages();applyHash();
})();
