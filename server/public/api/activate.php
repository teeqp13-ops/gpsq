<?php
declare(strict_types=1); require dirname(__DIR__,2).'/app/bootstrap.php'; require_post(); require_api_key($config);
$input=request_input(); $code=normalize_code((string)($input['code']??'')); $device=trim((string)($input['device_uuid']??$input['uuid']??'')); $source=trim((string)($input['bundle_id']??$input['source_id']??''));
if($code===''||$device==='') json_response(['status'=>'error','message'=>'الكود ومعرف الجهاز مطلوبان'],422);
$s=$db->prepare('SELECT * FROM licenses WHERE code=?');$s->execute([$code]);$l=$s->fetch();
if(!$l) json_response(['status'=>'error','message'=>'الكود غير موجود'],404);
if($l['status']!=='active') json_response(['status'=>'error','message'=>'الكود غير فعال'],403);
if($l['device_uuid']&&!hash_equals((string)$l['device_uuid'],$device)) json_response(['status'=>'error','message'=>'الكود مرتبط بجهاز آخر'],409);
if($source!==''&&!empty($l['source_id'])&&!hash_equals((string)$l['source_id'],$source)) json_response(['status'=>'error','message'=>'الكود مرتبط بسورس أداة آخر'],409);
if(!$l['activated_at']){$a=date('Y-m-d H:i:s');$e=date('Y-m-d H:i:s',strtotime('+'.(int)$l['duration_days'].' days'));$u=$db->prepare('UPDATE licenses SET device_uuid=?,activated_at=?,expires_at=?,last_seen_at=?,source_id=COALESCE(source_id,?),source_bound_at=COALESCE(source_bound_at,?) WHERE id=?');$u->execute([$device,$a,$e,$a,$source!==''?$source:null,$source!==''?$a:null,$l['id']]);$l['activated_at']=$a;$l['expires_at']=$e;$l['device_uuid']=$device;$l['source_id']=$source;} else {$now=date('Y-m-d H:i:s');$db->prepare('UPDATE licenses SET last_seen_at=?,source_id=CASE WHEN source_id IS NULL OR source_id="" THEN ? ELSE source_id END,source_bound_at=CASE WHEN source_bound_at IS NULL AND ?<>"" THEN ? ELSE source_bound_at END WHERE id=?')->execute([$now,$source,$source,$now,$l['id']]);}
if($l['expires_at']&&strtotime($l['expires_at'])<time()) json_response(['status'=>'error','message'=>'انتهى الاشتراك'],403);
json_response(['status'=>'success','message'=>'تم قبول الكود','active'=>true,'start_date'=>$l['activated_at'],'expiration_date'=>$l['expires_at'],'device_uuid'=>$l['device_uuid'],'source_id'=>$l['source_id']??$source,'source_locked'=>true]);
