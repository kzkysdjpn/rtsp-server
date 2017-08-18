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
