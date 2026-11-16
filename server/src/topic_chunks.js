// Limits apply to headings text, never full PDF bytes.
export const MAX_HEADING_CHARACTERS = 12000;
export const MAX_CHUNKS = 3;
export const TARGET_CHUNK_CHARACTERS = 4000;
export const MAX_CHUNK_CHARACTERS = 6000;
export const TOPICS_PER_CHUNK = 20;
export const MAX_COMPLETION_TOKENS = 2048;

export function splitHeadings(text) {
 const input=text.trim();
 if(!input || input.length>MAX_HEADING_CHARACTERS)throw new Error('invalid headings length');
 const lines=input.split(/\r?\n/).filter(line=>line.trim()).length;
 const count=Math.min(MAX_CHUNKS,Math.max(Math.ceil(input.length/TARGET_CHUNK_CHARACTERS),Math.ceil(lines/TOPICS_PER_CHUNK)));
 const chunks=[];let remaining=input;
 for(let slots=count;slots>1;slots--){
  const min=Math.max(1,remaining.length-(slots-1)*MAX_CHUNK_CHARACTERS);
  const max=Math.min(MAX_CHUNK_CHARACTERS,remaining.length-(slots-1));
  const target=Math.ceil(remaining.length/slots);
  const ends=[...remaining.matchAll(/\n/g)].map(match=>match.index+1);
  const lineCount=ends.length+(remaining.endsWith('\n')?0:1);
  let cut=ends[Math.ceil(lineCount/slots)-1]??target;
  if(cut<min || cut>max){
   const next=remaining.indexOf('\n',target);
   cut=next>=0&&next+1<=max?next+1:target;
  }
  // Never split a UTF-16 surrogate pair when no line boundary is available.
  const left=remaining.charCodeAt(cut-1),right=remaining.charCodeAt(cut);
  if(left>=0xd800&&left<=0xdbff&&right>=0xdc00&&right<=0xdfff)cut+=cut<max?1:-1;
  chunks.push(remaining.slice(0,cut));remaining=remaining.slice(cut);
 }
 chunks.push(remaining);
 return chunks.filter(part=>part.trim());
}

export function mergeTopics(topics) {
 const result=[];
 const key=title=>title.normalize('NFKC').replace(/\s+/g,' ').trim().toLowerCase();
 for(const topic of topics){
  const matches=result.filter(prior=>key(prior.title)===key(topic.title)&&
    prior.startPage<=topic.endPage+1&&topic.startPage<=prior.endPage+1);
  if(!matches.length){result.push({...topic});continue;}
  const merged={title:matches[0].title,
    startPage:Math.min(topic.startPage,...matches.map(x=>x.startPage)),
    endPage:Math.max(topic.endPage,...matches.map(x=>x.endPage))};
  const first=result.indexOf(matches[0]);
  for(const match of matches)result.splice(result.indexOf(match),1);
  result.splice(first,0,merged);
 }
 return result.sort((a,b)=>a.startPage-b.startPage||a.endPage-b.endPage).slice(0,60);
}
