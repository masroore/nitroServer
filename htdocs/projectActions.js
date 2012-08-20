/*
	BDS Welcome Page - Project Actions Module

	Copyright (c) 2004, 2005 Borland Software Corporation

	Written by Daniel Wischnewski, Borland SE Germany.
	Co-Admin of www.delphipraxis.net -- The German Delphi Community
	Email: dwischnewski@gatenetwork.com
*/

function openProject()
{
	external.Application.MainForm.FileOpenProjectItem.Click;
}

function newProject()
{
	external.Application.MainForm.FileNewItem.Click;
}

function openFile()
{
	external.Application.MainForm.FileOpenItem.Click;
}

function newFile()
{
	external.Application.MainForm.SearchFileFindItem.Click;
}

function viewPrjMgrItem()
{
	external.Application.MainForm.ViewPrjMgrItem.Click;
}

function openHelp()
{
	external.Application.MainForm.HelpInprisePage.Click;
}

function openHelpCSTutorial()
{
	external.Application.MainForm.HelpCsTutorialItem.Click;
}

function openFileLink(fileName)
{
	try
	{
		external.Application.OpenFile(fileName);
	} catch(e) {
		debugAlert(e.message);
	}
}

function openDExplore(aLink)
{
	var session;
	session = new ActiveXObject("DExplore.AppObj.8.0");
	session.SetCollection("ms-help://borland.bds5", "");
	session.Contents();
	session.DisplayTopicFromUrl(aLink);
}

//file manipulation functions
function ExtractPathedFileFromCaption(FileString)
{
	return FileString.substring(FileString.indexOf(' ') + 1, FileString.length);
}

function ExtractValuesFromKeyString(KeyString)
{
	var KeyStringArray = new Array();
	KeyStringArray = KeyString.split(',');
	return KeyStringArray;
}

function clickMenu(Index)
{
	var MenuItem = external.Application.MainForm.FileClosedFilesItem.GetItems(Index);
	if (MenuItem != null)
	{
		MenuItem.Click;
	}
    try
    {
		window.setTimeout("renderProjectsModule();", 1000);
    }
    catch(e)
    {
		debugAlert(e.message);
    }
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

function getFileModifiedString(PathedFile)
{
	if(fileSystemObject != null)
	{
		if(fileSystemObject.FileExists(PathedFile))
		{
			var fModified = false;
			var objDateFile = new Date(fileSystemObject.GetFile(PathedFile).DateLastModified);
			return objDateFile.toLocaleDateString();
		} else {
			return "File not found";
		}
	} else {
		return "Unable to read file date";
	}
}

function GetFileExtension(filename)
{
	return filename.substring(filename.lastIndexOf("."));
}

var pt_Group = 1;
var pt_D32 = 2;
var pt_DNet = 3;
var pt_CS = 4;
var pt_VB = 5;
var pt_CPP = 6;
var pt_Design = 7;
var pt_Other = 100;

function projectType(filename)
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
		var xmlDoc = loadXmlDocSafe(filename)
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
	return pt_Other
}

function renderProjectsModule()
{
	var xmlProjects;
	var xmlChannel;
	var xmlDoc;
	var rowCount;
	var reOpenMenu;
	var pType;
	var projects;

	reOpenMenu = external.Application.MainForm.FileClosedFilesItem;
	xmlProjects = getXmlDoc();
	xmlProjects.loadXML('<rss version="2.0" />');
	xmlChannel = getSubNode(xmlProjects.documentElement, 'channel');
	reOpenMenu = external.Application.MainForm.FileClosedFilesItem;

	rowCount = reOpenMenu.Count();
	for(var i = 0; i < rowCount ; i++)
	{
		var menuItem = reOpenMenu.GetItems(i);
		var menuText = getMenuText(menuItem.Caption, menuItem.MenuItemIndex);
		var fileName = ExtractPathedFileFromCaption(menuItem.Caption);
		if (menuText != '' && fileSystemObject != null && fileSystemObject.FileExists(fileName))
		{
			var itemNode = xmlChannel.appendChild(xmlProjects.createElement('item'));
			pType = projectType(fileName);
			getSubNode(itemNode, 'personality').text = pType;
			getSubNode(itemNode, 'personalityName').text = pType;
			if (pType == 1)
			{
				xmlDoc = loadXmlDoc(fileName);
				if (xmlDoc.parseError.errorCode == 0)
				{
					projects = xmlDoc.documentElement.selectNodes('Default.Personality/Projects/Projects[@Name != "Targets"]');
					for (var j = 0; j < projects.length; j++)
					{
						itemNode.appendChild(projects[j]);
					}
				}
			}
			getSubNode(itemNode, 'title').text = menuText;
			getSubNode(itemNode, 'file').text = fileName;
			getSubNode(itemNode, 'index').text = i;
			getSubNode(itemNode, 'lastChange').text = getFileModifiedString(fileName);
		}
	}
	displayRss(tableContainer, xmlProjects, loadLocalXslDoc('projects.xsl'));
}