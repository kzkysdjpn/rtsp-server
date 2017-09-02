$(document).ready(function(){
	setupParams();
	return;
});

function setupParams()
{
	$.ajax({
		type:         'get',
		url:          'admin_config.json',
		contentType:  'application/JSON',
		dataType:     'JSON',
		scriptCharset:'utf-8',
		success:      function(data){
			loadAdminConfigParams(data);
			return;
		},
		error:        function(data){
			return;
		}
	});

	return;
}

function loadAdminConfigParams(data)
{
	$('#USERNAME').val(data['AUTH_INFO']['USERNAME']);
	$('#PASSWORD').val("********");
	$('#BIND_PORT').val(data['BIND_PORT']);

	return;
}

function onApplyAdministratorSettings()
{
	var JSONData = {
		BIND_PORT: $('#BIND_PORT').val(),
		AUTH_INFO: {
			USERNAME: $('#USERNAME').val(),
			PASSWORD: $('#PASSWORD').val()
		}
	};

	open_block_ui('Please close this page and wait a minute.');
	$.ajax({
		type:         'post',
		url:          'admin_settings_apply.json',
		data:         JSON.stringify(JSONData),
		contentType:  'application/JSON',
		dataType:     'JSON',
		scriptCharset:'utf-8',
		success:      function(data){
			statusReplyAdministratorSettings(data);
			return;
		},
		error:        function(data){
			return;
		}
	});

	return;
}

function statusReplyAdministratorSettings(data)
{
	if(('STATUS' in data) == false){
		return;
	}
	if(data['STATUS'] == true){
		return;
	}
	close_block_ui();
	if(('MESSAGE' in data) == false){
		return;
	}
	alert(data['MESSAGE']);

	return;
}

function onCompletelyExitApp()
{
	var ret;

	ret = confirm("Will you terminate this application, completely ?");
	if(ret == false){
		return;
	}
	$.ajax({
		type:         'get',
		url:          'admin_terminate_app.json',
		contentType:  'application/JSON',
		dataType:     'JSON',
		scriptCharset:'utf-8',
		success:      function(data){
			statusReplyAdministratorSettings(data);
			return;
		},
		error:        function(data){
			return;
		}
	});

	return;
}
