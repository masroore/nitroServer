/*
	BDS Welcome Page - Language dependend strings loader module

	Copyright (c) 2004, 2005 Borland Software Corporation

	Written by Daniel Wischnewski, Borland SE Germany.
	Co-Admin of www.delphipraxis.net -- The German Delphi Community
	Email: dwischnewski@gatenetwork.com
*/

var languageTexts;

function getLangText(id)
{
	var node;

	node = languageTexts.selectSingleNode('./item[guid="' + id + '"]');
	return getItemValue(node, "text");
}

function loadLanguageTexts(items)
{
	var domObject;
	var id;
	var innerHTML;
	var insertAt;

	for (var i = 0; i < items.length; i++)
	{
		id = getItemValue(items[i], "guid");
		innerHTML = getItemValue(items[i], "text");
		if (id != "" && innerHTML != "")
		{
			domObject = document.getElementById(id);
			if (domObject != null)
			{
				insertAt = getItemValue(items[i], "insertAt");
				if (insertAt == "")
				{
					try
					{
						domObject.innerHTML = innerHTML;
					} catch(e) {
						domObject.outerText = innerHTML;
					}
				} else {
					domObject.insertAdjacentHTML(insertAt, innerHTML);
				}
			}
		}
	}
}

function loadLanguageStrings()
{
	var languageStringsXml;
	var domObject;

	languageStringsXml = loadLocalXmlDoc('languageStrings.xml');
	loadLanguageTexts(languageStringsXml.documentElement.selectNodes('channel/item'));

	domObject = document.getElementById("offline");
	if (domObject != null)
	{
		try
		{
			domObject.title = languageStringsXml.documentElement.selectSingleNode('channel/item[guid="goonline"]/text').text;
		} catch(e) {
		}
	}
}
