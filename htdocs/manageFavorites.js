function createException(msgNum, msgText) {
	this.messageNumber = msgNum;
	this.message = msgText;
}

function checkUniqueGroupTitle(title) {
	loadFavoritesList();
	group = xmlProjectFavorites.documentElement.selectSingleNode('group[@title="' + title + '"]');
	if (group != null) {
		throw new createException(1, getLangString("titleNotUnique"));
	}
}

function ShowHide(elem, value) {
	var c;

	switch(value) {
		case "autoShow": {
			c = elem.className;
			elem.className = (c)?c.replace(regHide, "") : "";
			break;
		}
		case "autoHide": {
			c = elem.className;
			if (c.search(regHide) < 0) {
				elem.className = (c)?c + ' ' + classHide : classHide;
			}
			break;
		}
	}
}

function autoDisplay() {
	try {
		var elems = ContentArea.getElementsByTagName("div");
		for (var i = 0; i < elems.length; i++) {
			var attr = elems[i].attributes.getNamedItem("name");
			if (attr != null)	{
				ShowHide(elems[i], attr.value);
			}
		}

		var elems = ContentArea.getElementsByTagName("span");
		for (var i = 0; i < elems.length; i++) {
			var attr = elems[i].attributes.getNamedItem("name");
			if (attr != null)	{
				ShowHide(elems[i], attr.value);
			}
		}
	} catch(e) {
		debugAlert("autoDisplay: " + e.message);
	}
}

function EditFavTitle(elem) {
	autoDisplay();

	var topDIV = elem.parentNode.parentNode.parentNode;
	var c = topDIV.getElementsByTagName("div")[0].className;
	topDIV.getElementsByTagName("div")[0].className = (c)?c + ' ' + classHide : classHide;

	var c = topDIV.getElementsByTagName("div")[1].className;
	topDIV.getElementsByTagName("div")[1].className = (c)?c.replace(regHide, '') : '';
}

function SetFavTitle(elem, doSet) {
	try {
		var topDIV = elem.parentNode.parentNode.parentNode;
		if (doSet) {
			var title = topDIV.getElementsByTagName("input")[0].value;
			var oldTitle = topDIV.getElementsByTagName("input")[1].value;

			if (title != oldTitle) {
				checkUniqueGroupTitle(title);
	
				topDIV.getElementsByTagName("span")[0].innerHTML = title;
				topDIV.getElementsByTagName("input")[1].value = title;
		
				loadFavoritesList();
				group = xmlProjectFavorites.documentElement.selectSingleNode('group[@title="' + oldTitle + '"]');
				setAttrValue(group, 'title', title);
		
				saveFavoritesList();
				loadMyFavoritesList();
			}
		} else {
			var title = topDIV.getElementsByTagName("input")[1].value;
			topDIV.getElementsByTagName("input")[0].value = title;
		}
	
		var c = topDIV.getElementsByTagName("div")[0].className;
		topDIV.getElementsByTagName("div")[0].className = (c)?c.replace(regHide, '') : '';
	
		var c = topDIV.getElementsByTagName("div")[1].className;
		topDIV.getElementsByTagName("div")[1].className = (c)?c + ' ' + classHide : classHide;
	} catch(e) {
		alert(e.message);
	}
}

function getGroupFromFile(elem) {
	while (elem.nodeName.toLowerCase() != "div")
	{
		elem = elem.parentNode;
	}
	return elem.parentNode.getElementsByTagName("input")[1].value;
}

function unmakeProjectFavorite(elem, projectFile) {
	var projectNode;

	autoDisplay();

	try {
		var groupTitle = getGroupFromFile(elem);
		elem.parentNode.removeNode(elem.parentNode);

		projectNode = xmlProjectFavorites.documentElement.selectSingleNode('group[@title="' + groupTitle.replace(/\\/gi, '\\\\') + '"]/project[@location="' + projectFile.replace(/\\/gi, '\\\\') + '"]');
		if (projectNode != null) {
			projectNode.parentNode.removeChild(projectNode);
			saveFavoritesList();
		}

		loadMyFavoritesList();
	} catch(e) {
		debugAlert("unmakeProjectFavorite: " + e.message);
	}
}

function removeFavoriteGroup(elem, groupTitle) {
	var projectNode;

	autoDisplay();

	try {
		loadFavoritesList();
		var oldTitle = elem.parentNode.parentNode.parentNode.getElementsByTagName("input")[0].value;
		group = xmlProjectFavorites.documentElement.selectSingleNode('group[@title="' + oldTitle + '"]');
		if (group != null) {
			group.parentNode.removeChild(group);
		}

		elem.parentNode.parentNode.parentNode.parentNode.removeNode(elem.parentNode.parentNode.parentNode);

		saveFavoritesList();
		loadMyFavoritesList();
	} catch(e) {
		debugAlert("removeFavoriteGroup: " + e.message);
	}
}

function CreateFavGroup(elem) {
	autoDisplay();

	try {
		var input = elem.parentNode.getElementsByTagName('input')[0];
		if (input.value == "") {
			throw new createException(2, getLangString("noGroupTitle"));
		}
		checkUniqueGroupTitle(input.value);
		
		loadFavoritesList();
		getSubNodeEx(xmlProjectFavorites.documentElement, "group", "title", input.value);
		saveFavoritesList();
		callProjectManageFavs();
		loadMyFavoritesList();
	} catch(e) {
		alert(e.message);
	}
}

function moveFavoriteToShow(elem) {
	try {
		var group = getGroupFromFile(elem);
		var move = elem.parentNode.getElementsByTagName("span")[0];
		var c = move.className;
		if (!(c)) {
			c = "";
		}
		autoDisplay();
		move.className = (c.search(regHide) < 0)?c + " " + classHide : c.replace(regHide, "");
		
		var selBox = elem.parentNode.getElementsByTagName("select")[0];
		selBox.options.length = 0;
		
		loadFavoritesList();
		var groups = xmlProjectFavorites.documentElement.selectNodes('group');
		for (var i = 0; i < groups.length; i++) {
			var title = groups[i].selectSingleNode("@title").text;
			selBox.options[selBox.options.length] = new Option(title, title);
			if (title == group) {
				selBox.selectedIndex = i;
			}
		}
	} catch(e) {
		debugAlert("moveFavoriteToShow: " + e.message);
	}
}

function moveFavoriteTo(elem, fileName) {
	try {
		var group = getGroupFromFile(elem);
		if (elem.value != group) {
			loadFavoritesList();
			var oldGroup = xmlProjectFavorites.documentElement.selectSingleNode('group[@title="' + group + '"]');
			var newGroup = xmlProjectFavorites.documentElement.selectSingleNode('group[@title="' + elem.value + '"]');
			var file = xmlProjectFavorites.documentElement.selectSingleNode('group[@title="' + group + '"]/project[@location="' + fileName.replace(/\\/gi, '\\\\') + '"]');
			if ((oldGroup == null) || (newGroup == null) || (file == null))	{
				autoDisplay();
				throw new createException(3, getLangString("groupFileNotFound"));
			}
			
			newGroup.appendChild(oldGroup.removeChild(file));
			saveFavoritesList();
			callProjectManageFavs();
			loadMyFavoritesList();
		}
	} catch(e) {
		debugAlert("moveFavoriteTo: " + e.message);
	}
}

