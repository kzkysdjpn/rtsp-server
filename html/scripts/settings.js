$(document).ready(function(){
	setupParams();
	return;
});

function setupParams()
{
	$.ajax({
		type:         'get',
		url:          'server_config.json',
		contentType:  'application/JSON',
		dataType:     'JSON',
		scriptCharset:'utf-8',
		success:      function(data){
			loadServerConfigParams(data);
			loadAuthUserInfo(data);
			return;
		},
		error:        function(data){
			return;
		}
	});

	return;
}

function loadServerConfigParams(data)
{
	var i;
	var params_key = [ 
		'RTSP_SOURCE_PORT',
		'ON_RECEIVE_COMMAND',
		'RTP_START_PORT'
	];
	for(i = 0; i < params_key.length ; i++){
		$('#' + params_key[i]).val(data[params_key[i]]);
	}
	if(data['USE_SOURCE_AUTH'] == true){
		$('input[name="USE_SOURCE_AUTH"]').prop('checked', true);
	}else{
		$('input[name="USE_SOURCE_AUTH"]').prop('checked', false);
	}
	return;
}

function loadAuthUserInfo(data)
{
	var	i;
	for(i = 0; i < data['SOURCE_AUTH_INFO_LIST'].length; i++){
		$('#auth_user_list').append(authUserRowData(data['SOURCE_AUTH_INFO_LIST'][i]));
	}
	return;
}

function authUserRowData(dataRow)
{
	var row = '<tr><td scope="row"><input style="width:30px;" type="radio" name="auth_list" value="' + dataRow['USERNAME'] + '">' + dataRow['USERNAME'] + '</input></td>' +
		'<td>' + dataRow['SRC_NAME']  + '</td></tr>';
	return row;
}

function onApplyRTSPServerSettings()
{
	var JSONData = {
		RTSP_SOURCE_PORT: $('#RTSP_SOURCE_PORT').val(),
		ON_RECEIVE_COMMAND: $('#ON_RECEIVE_COMMAND').val(),
		RTP_START_PORT: $('#RTP_START_PORT').val(),
		USE_SOURCE_AUTH: $('input[name="USE_SOURCE_AUTH"]').prop('checked')
	};
	open_block_ui('Please Wait.....');
	$.ajax({
		type:         'post',
		url:          'server_settings_apply.json',
		data:         JSON.stringify(JSONData),
		contentType:  'application/JSON',
		dataType:     'JSON',
		scriptCharset:'utf-8',
		success:      function(data){
			statusApplyRTSPServerSettings(data);
			return;
		},
		error:        function(data){
			return;
		}
	});

	return;
}

function statusApplyRTSPServerSettings(data)
{
	location.reload(true);
	return;
}

function onAddUserRTSPServerSettings()
{
	var JSONData = {
		USERNAME: $('#USERNAME').val(),
		PASSWORD: $('#PASSWORD').val(),
		SRC_NAME: $('#SRC_NAME').val()
	};
	open_block_ui('Please Wait.....');
	$.ajax({
		type:         'post',
		url:          'server_auth_add_user.json',
		data:         JSON.stringify(JSONData),
		contentType:  'application/JSON',
		dataType:     'JSON',
		scriptCharset:'utf-8',
		success:      function(data){
			statusAddUserRTSPServerSettings(data);
			return;
		},
		error:        function(data){
			return;
		}
	});

	return;
}

function statusAddUserRTSPServerSettings(data)
{
	if(('STATUS' in data) == false){
		return;
	}
	if(data['STATUS'] == true){
		location.reload(true);
		return;
	}
	close_block_ui();
	if(('MESSAGE' in data) == false){
		return;
	}
	alert(data['MESSAGE']);
	return;
}
