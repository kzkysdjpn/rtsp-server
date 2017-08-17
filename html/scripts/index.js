$(document).ready(function(){
	setupParams();
	return;
});

function setupParams()
{
	$.ajax({
		type:         'get',
		url:          'source_table_list.json',
		contentType:  'application/JSON',
		dataType:     'JSON',
		scriptCharset:'utf-8',
		success:      function(data){
			loadSourceParams(data);
			return;
		},
		error:        function(data){
			return;
		}
	});

	$.ajax({
		type:         'get',
		url:          'server_address_info.json',
		contentType:  'application/JSON',
		dataType:     'JSON',
		scriptCharset:'utf-8',
		success:      function(data){
			loadServerAddressParams(data);
			return;
		},
		error:        function(data){
			return;
		}
	});

	return;
}

function loadSourceParams(data)
{
	var	i;
	for(i = 0; i < data.length; i++){
		$('#source_table_list').append(sourceRowData(data[i]));
	}
	return;
}

function sourceRowData(dataRow)
{
	var row = '<tr><td scope="row"><a ref="#" onclick="onStartView(\'' +
		dataRow['SOURCE_NAME'] + '\')">' +
		dataRow['SOURCE_NAME'] + '</a></td>' +
		'<td>' + dataRow['HOST']  + '</td>' +
		'<td>' + dataRow['DATE']  + '</td>' +
		'<td>' + dataRow['PID']   + '</td>' +
		'<td>' + dataRow['COUNT'] + '</td></tr>';
	return row;
}

function loadServerAddressParams(data)
{
	var	i;
	for(i = 0; i < data['IP'].length; i++){
		$('#server_address_list').append(serverAddressRowData(data['IP'][i], data['PORT']));
	}
	$('#rtsp_client_port').val(data['CLIENT_PORT']);
	return;
}

function serverAddressRowData(ip, port)
{
	var row = '<tr><td scope="row">' + ip + '</td>' +
		'<td>' + port + '</td></tr>';
	return row;
}

function onStartView(source_name)
{
	alert("source name is " + source_name);
	alert($('#rtsp_client_port').val());
	return;
}
