var pt_Group = 1;
var pt_D32 = 2;
var pt_DNet = 3;
var pt_CS = 4;
var pt_VB = 5;
var pt_CPP = 6;
var pt_Design = 7;
var pt_Other = 100;

var xmlProjectFavorites = null;

function registerProjectLinks() {
	loadFavoritesList();
	persistentMenuCalls.push('{29C682DC-AC59-4EFE-925F-C8318C62B219}', callProjectDetails);
	persistentMenuCalls.push('{08D4336C-D636-42C9-AED4-CDA1EA26BF4B}', callProjectFavorites);
	persistentMenuCalls.push('{E8175EB7-6FB1-4AE1-B0F2-85F610538EB1}', callProjectManageFavs);
}

function loadFavoritesList() {
	if (xmlProjectFavorites == null) {
		xmlProjectFavorites = loadXmlDocSafe(clientAppDataFolder + '\\myFavorites.xml');
	}
}

function saveFavoritesList() {
	if (xmlProjectFavorites != null) {
		xmlProjectFavorites.save(clientAppDataFolder + '\\myFavorites.xml');
	}
}

function reloadProjects(blnDetailed) {
	if (blnDetailed) {
		callProjectDetails();
	} else {
		loadProjectsList();
	}
}

function callProjectDetails() {
	var projects;

	projects = getXmlDoc();
	projects.loadXML("<rss />");
	displayRss(ContentHeader, loadLocalXmlDoc('menuProjects.xml'), loadLocalXslDoc('contentMenu.xsl'));
	getProjectRss(projects, true);
	displayRss(ContentArea, projects, loadLocalXslDoc('rssProjects.xsl'));
}

function callProjectFavorites() {
	var favorites;

	favorites = getXmlDoc();
	favorites.loadXML("<rss />");
	displayRss(ContentHeader, loadLocalXmlDoc('menuFavorites.xml'), loadLocalXslDoc('contentMenu.xsl'));
	getFavoriteRss(favorites);
	displayRss(ContentArea, favorites, loadLocalXslDoc('rssFavorites.xsl'));
}

function callProjectManageFavs() {
	var favorites;

	favorites = getXmlDoc();
	favorites.loadXML("<rss />");
	displayRss(ContentHeader, loadLocalXmlDoc('menuManageFavs.xml'), loadLocalXslDoc('contentMenu.xsl'));
	getFavoriteRss(favorites);
	displayRss(ContentArea, favorites, loadLocalXslDoc('rssManageFavs.xsl'));
}

function loadProjectsList() {
	var projects;

	projects = loadLocalXmlDoc('recentProjects.xml');
	getProjectRss(projects, false);
	displayRss(menuProjectGroup, projects, loadLocalXslDoc('menuGroupBar.xsl'));
}

function loadMyFavoritesList() {
	var favorites;

	favorites = loadLocalXmlDoc('favorites.xml');
	getFavoriteRss(favorites, false);
	displayRss(menuMyFavorites, favorites, loadLocalXslDoc('menuGroupBarFavs.xsl'));
}

function getProjectRss(xmlProjects, blnDetailed) {
	var reOpenMenu;
	var xmlChannel;
	var rowCount;
	var menuItem;
	var menuText;
	var fileName;
	var itemNode;
	var projectType;
	var xmlDoc;
	var projects;
	var fav;

	reOpenMenu = external.Application.MainForm.FileClosedFilesItem;
	xmlChannel = getSubNode(xmlProjects.documentElement, 'channel');
	rowCount = reOpenMenu.Count();
	for (var i = 0; i < rowCount ; i++)
	{
		menuItem = reOpenMenu.GetItems(i);
		menuText = getMenuText(menuItem.Caption, menuItem.MenuItemIndex);
		fileName = ExtractPathedFileFromCaption(menuItem.Caption).replace(/\&\&/gi, '&');
		if (menuText != '')
		{
			itemNode = xmlChannel.appendChild(xmlProjects.createElement('file'));
			getSubNode(itemNode, 'fullTitle').text = fileName;
			getSubNode(itemNode, 'file').text = fileName.replace(/(\\)/gi, '\\');

			if (blnDetailed) {
				projectType = getProjectType(fileName);
				getSubNode(itemNode, 'personality').text = projectType;
				getSubNode(itemNode, 'personalityName').text = projectType;

				fav = xmlProjectFavorites.documentElement.selectSingleNode('.//project[@location="' + fileName.replace(/\\/gi, "\\\\") + '"]');
				if (fav == null ) {
					getSubNode(itemNode, "makeFavorite");
				}
				if (projectType == 1 && blnDetailed)
				{
					xmlDoc = loadXmlDoc(fileName);
					if (xmlDoc.parseError.errorCode == 0)
					try {
						projects = xmlDoc.documentElement.selectNodes('Default.Personality/Projects/Projects[@Name != "Targets"]');
						for (var j = 0; j < projects.length; j++)
						{
							itemNode.appendChild(projects[j]);
						}
					} catch(e) {}
				}
				getSubNode(itemNode, 'folder').text = fileName.substring(0, fileName.lastIndexOf("\\"));
	
				getSubNode(itemNode, 'title').text = menuText;
				getSubNode(itemNode, 'lastChange').text = getFileModifiedString(fileName);
			} else {
				getSubNode(itemNode, 'title').text = menuText.substring(0, menuText.lastIndexOf("."));
			}
		}
	}
}

function getFavoriteRss(xmlProjects){
	var lstProjects;
	var xmlChannel;
	var rowCount;
	var menuItem;
	var menuText;
	var fileName;
	var itemNode;
	var projectType;
	var xmlDoc;
	var projects;
	var fav;
	var lstGroups;
	var nodeGroup;

	loadFavoritesList();
	xmlChannel = getSubNode(xmlProjects.documentElement, 'channel');
	lstGroups = xmlProjectFavorites.documentElement.selectNodes('group');
	for (var j = 0; j < lstGroups.length; j++)
	{
		nodeGroup = xmlChannel.appendChild(xmlProjects.createElement('group'));
		nodeGroup.appendChild(xmlProjects.createElement('title')).text = lstGroups[j].selectSingleNode('@title').text;
        def = nodeGroup.appendChild(xmlProjects.createElement('default'))
        if (getItemValue(lstGroups[j], '@default') != '')
    		def.text = getItemValue(lstGroups[j], '@default');
        else
            def.text = 0;

		lstProjects = lstGroups[j].selectNodes('project');
		rowCount = lstProjects.length;
		for (var i = 0; i < rowCount ; i++)
		{
			menuItem = lstProjects(i);
			menuText = menuItem.selectSingleNode('@location').text;
			fileName = menuText;
			if (menuText != '')
			{
				itemNode = nodeGroup.appendChild(xmlProjects.createElement('file'));
				getSubNode(itemNode, 'fullTitle').text = fileName;
				getSubNode(itemNode, 'file').text = fileName.replace(/(\\)/gi, '\\');
	
				projectType = getProjectType(fileName);
				getSubNode(itemNode, 'personality').text = projectType;
	
				getSubNode(itemNode, 'folder').text = fileName.substring(0, fileName.lastIndexOf("\\"));
	
				getSubNode(itemNode, 'title').text = menuText.substring(menuText.lastIndexOf("\\") + 1);
				getSubNode(itemNode, 'lastChange').text = getFileModifiedString(fileName);
			}
		}
	}
}

function getProjectType(filename)
{
	var fileExt = GetFileExtension(filename);

	var pattern = /\.bdsgroup/;
	if (pattern.test(fileExt))
	{
		return pt_Group;
	}

	var pattern = /\.bdsproj/;
	if (pattern.test(fileExt))
	{
		var xmlDoc = loadXmlDoc(filename)
		if (xmlDoc.parseError.errorCode == 0) {
			var Node = xmlDoc.documentElement.selectSingleNode("//Option[@Name=\"Personality\"]");
			if (Node != null) {
				switch (Node.text)
				{
					case "Delphi.Personality":
						return pt_D32;
						break;
					case "CPlusPlusBuilder.Personality":
						return pt_CPP;
						break;
					case "DelphiDotNet.Personality":
						return pt_DNet;
						break;
					case "CSharp.Personality":
						return pt_CS;
						break;
					case "VB.Personality":
						return pt_VB;
						break;
					case "Design.Personality":
						return pt_Design;
						break;
				}
			}
		}
	}
	return pt_Other
}

function getMenuText(Caption, Index)
{
	var Text = "";
	var Filename = "";

	if (Caption != "-")
	{
		var pick = Caption.substring(1, 2);
		if (pick < "5")
		{
			Text = Caption.substr(3);
		}
	}
	Filename = Text;
	var i = Text.lastIndexOf("\\");
	if (Text.length > 0 && i > 0)
	{
		Text = Text.substr(i + 1);
	}
	return Text;
}

function ExtractPathedFileFromCaption(FileString)
{
	return FileString.substring(FileString.indexOf(' ') + 1, FileString.length);
}

function getFileModifiedString(PathedFile)
{
	var fileSystemObject;

	fileSystemObject = new ActiveXObject("Scripting.FileSystemObject");
	if(fileSystemObject != null)
	{
		if(fileSystemObject.FileExists(PathedFile))
		{
			var fModified = false;
			var objDateFile = new Date(fileSystemObject.GetFile(PathedFile).DateLastModified);
			return objDateFile.toLocaleDateString() + " " + objDateFile.toLocaleTimeString();
		} else {
			return "FNF";
		}
	} else {
		return "FNF";
	}
}

function GetFileExtension(filename)
{
	return filename.substring(filename.lastIndexOf("."));
}

function openProject()
{
	external.Application.MainForm.FileOpenProjectItem.Click;
}

function newProject()
{
	external.Application.MainForm.FileNewItem.Click;
}

function openDExplore(aLink)
{
	var session;
	session = new ActiveXObject("DExplore.AppObj.8.0");
	session.SetCollection("ms-help://borland.bds5", "");
	session.Contents();
	session.DisplayTopicFromUrl(aLink);
}

function openFileLink(fileName)
{
	try {
		external.Application.OpenFile(fileName);
	} catch(e) {
		debugAlert("openFileLink: " + e.message);
	}
}

function makeProjectFavorite(favLink, projectFile) {
	var groupNode;
	var projectNode;

	try {
		groupNode = getSubNodeEx(xmlProjectFavorites.documentElement, "group", "default", "1");
		if (groupNode.selectSingleNode("@title") == null) {
			setAttrValue(groupNode, "title", getLangString("newFavorites"));
		}
		projectNode = getSubNodeEx(groupNode, "project", "location", projectFile);
		saveFavoritesList();
		reloadProjects(true);
		loadMyFavoritesList();
	} catch(e) {
		debugAlert("makeProjectFavorite: " + e.message);
	}
}

function showFavoriteGroup(elem) {
  var myDiv = elem.parentNode.getElementsByTagName("div")[0];
	var c = myDiv.className;
	var isShown = (c)?c.search(regHide) < 0 : true;
	var head;
	
	var topDIV = elem.parentNode.parentNode;
	var allDivs = topDIV.getElementsByTagName("div");
	for (var i = 0; i < allDivs.length; i++) {
		if (allDivs[i].parentNode == topDIV)
		{
			var div = allDivs[i].getElementsByTagName("div")[0];
			head = allDivs[i].getElementsByTagName("h2")[0];
			var ac = div.className;
			if (ac.search(regHide) < 0) {
				div.className = (ac)?ac + ' ' + classHide : classHide;
			}
			head.className = div.className.search(regHide)>=0?"up":"down";
		}
	}
	
	myDiv.className = (isShown)?c + ' ' + classHide:c.replace(regHide, '');
  head = elem.parentNode.getElementsByTagName("h2")[0];
	head.className = myDiv.className.search(regHide)>=0?"up":"down";
}
