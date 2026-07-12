<?php
declare(strict_types=1); require dirname(__DIR__,2).'/app/bootstrap.php'; require_post(); require_api_key($config);
$input=request_input(); $code=normalize_code((string)($input['code']??'')); $device=trim((string)($input['device_uuid']??$input['uuid']??'')); $source=trim((string)($input['bundle_id']??$input['source_id']??''));
$l=validate_license($db,$code,$device,$source); $db->prepare('UPDATE licenses SET last_seen_at=? WHERE id=?')->execute([date('Y-m-d H:i:s'),$l['id']]);
json_response(['status'=>'success','active'=>true,'start_date'=>$l['activated_at'],'expiration_date'=>$l['expires_at'],'device_uuid'=>$l['device_uuid']]);
