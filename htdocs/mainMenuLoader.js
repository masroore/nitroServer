var menuProjectGroup;
var menuBarGroup;
var persistentMenuCalls = new Array();

function loadMenus() {
	menuBarGroup = document.getElementById('menuBarGroup');
	menuProjectGroup = document.getElementById('menuProjectGroup');

	clearMenuList();
	loadMenuLists();
}

function clearMenuList() {
	clearElementContent(mainMenu);
}

function loadMenuLists() {
	displayRss(mainMenu, loadLocalXmlDoc('menuMain.xml'), loadLocalXslDoc('menuMain.xsl'));
}

function menuPersistCall(guid)
{
	getSubNode(nodeSettings, 'lastMenuGuid').text = guid;
	savePersonalSettings();
	menuGuidCall(guid);
}

function menuGuidCall(guid) {
	var i;

	if (guid == '')
	{
		guid = getPersistedGuid();
	}
	try {
		i = 0;
		while (i < persistentMenuCalls.length) {
			if (persistentMenuCalls[i] == guid) {
				persistentMenuCalls[++i]();
			}
			i += 2;
		}
	} catch(e) {
		debugAlert("menuGuidCall: " + e.message);
	}
}

function getPersistedGuid() {
	var guid;

	guid = getSubNode(nodeSettings, 'lastMenuGuid').text;
	if (guid == '')
	{
		guid = '{29C682DC-AC59-4EFE-925F-C8318C62B219}';
	};

	return guid;
}

function MouseEnterMenuItem(elem) {
	var c, cs='menuVisible';
	
	c = elem.className;
	cl = (c)?c + ' ' + cs :cs;
	elem.className = cl;
}

function MouseLeaveMenuItem(elem) {
	var c, r=/\s*menuVisible/;

	c = elem.className;
	elem.className = (c)?c.replace(r, '') : '';
}
