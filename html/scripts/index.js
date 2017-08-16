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
			loadParams(data);
			return;
		},
		error:        function(data){
			return;
		}
	});

	return;
}

function loadParams(data)
{
	var	i;
	for(i = 0; i < data.length; i++){
		$('#source_table_list').append(rowData(data[i]));
	}
	return;
}

function rowData(dataRow)
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

function onStartView(source_name)
{
	alert("source name is " + source_name);
	return;
}
