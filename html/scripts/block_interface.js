function open_block_ui(msg)
{
	$.blockUI({
		message: msg,
		css: {
			border: 'none', 
			padding: '15px', 
			backgroundColor: '#000', 
			'-webkit-border-radius': '10px', 
			'-moz-border-radius': '10px', 
			opacity: .9, 
			color: '#fff' 
		}
	}); 
	return;
}

function close_block_ui()
{
	$.unblockUI();
	return;
}
