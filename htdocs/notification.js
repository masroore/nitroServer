var xmlNotification;
var intNotificationId;

function registerNotificationLinks() {
	xmlNotification = getXmlDoc();
	xmlNotification.loadXML('<xml />');
	intNotificationId = 0;
}

function displayNotification() {
	var nodes;
	var docNode;
	
	try {
		docNode = document.getElementById('menuNotificationGroup');
		nodes = xmlNotification.documentElement.selectNodes('*');
		if (nodes.length > 0) {
			displayRss(docNode, xmlNotification, loadLocalXslDoc('menuNotificationBar.xsl'));
		} else {
			docNode.innerHTML = '';
		}
	} catch(e) {
		alert("displayNotification: " + e.message);
	}
}

function getNotification(selfRemove) {
	var node;
	
	intNotificationId++;
	if (selfRemove) {
		return node = getSubNodeEx(xmlNotification.documentElement, 'action', 'id', intNotificationId);
	} else {
		return node = getSubNodeEx(xmlNotification.documentElement, 'item', 'id', intNotificationId);
	}
}

function removeNotification(node) {
	try {
		xmlNotification.documentElement.removeChild(node);
	} catch(e) {};
	displayNotification();
}

function clearNotification() {
	var nodes;
	var i;
	
	nodes = xmlNotification.documentElement.selectNodes('item');
	for (i = 0; i < nodes.length; i++) {
		try {
			xmlNotification.documentElement.removeChild(nodes[i]);
		} catch(e) {}
	}
	displayNotification();
}