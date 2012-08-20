function registerOrLinks() {
	persistentMenuCalls.push('{3951A275-F4BC-4B60-9EED-ADE5D23E4A68}', callOrSearch);
	persistentMenuCalls.push('{3E1B64D0-494C-4430-9653-7130D109D66C}', callOrCodeGearUpdates);
	persistentMenuCalls.push('{7CD0CA07-4C8F-4F50-A95B-4FB196D0B3D7}', callOrPartnerLinks);
	persistentMenuCalls.push('{87D89E68-DE75-439E-AC31-D94481DDABBA}', callOrReadMe);
	persistentMenuCalls.push('{38ABF9C1-DBB5-4A87-B267-0CD4CFCEC29E}', callOrYAPP);
}

function callOrReadMe() {
	displayRss(ContentHeader, loadLocalXmlDoc('readMeTitle.xml'), loadLocalXslDoc('contentMenu.xsl'));
	displayRss(ContentArea, loadLocalXmlDoc('gettingStarted.xml'), loadLocalXslDoc('rssFeeds.xsl'));
}

function callOrSearch() {
	alert('callOrSearch');
}

function callOrYAPP() {
	displayRss(ContentHeader, loadLocalXmlDoc('menuYAPP.xml'), loadLocalXslDoc('contentMenu.xsl'));
	displayRss(ContentArea, loadLocalXmlDoc('formYAPP.xml'), loadLocalXslDoc('rssForms.xsl'));

	try {
		var url = "http://lingua.codegear.com/yapp/ws/yapp.asmx";
		var pl = new SOAPClientParameters();

		showWait();
		SOAPClient.invoke(url, "GetSupportedLanguages", pl, true, callOrGetSupportedLanguages_callBack);
	} catch(e) {
		debugAlert("callOrYAPP: " + e.message);
	}
}

function callOrGetSupportedLanguages_callBack(r) {
	try {
		var obj = document.getElementById('xForm_LanguageType');
		
		for (var i = 0; i < r.length; i++) {
			var option = new Option(r[i].substring(2), r[i]);
			obj.options[obj.options.length] = option;
		}
		obj.options[1].selected = true;
	} catch(e) {
		debugAlert("callOrGetSupportedLanguages_callBack: " + e.message);
	}
	hideWait();
}

function callOrYAPPConverter() {
	try {
		var url = "http://lingua.codegear.com/yapp/ws/yapp.asmx";
		var pl = new SOAPClientParameters();

		showWait();

		pl.add("SourceCode", document.getElementById('xForm_SourceCode').value);
		pl.add("LanguageType", document.getElementById('xForm_LanguageType').value);
		pl.add("StartingLine", document.getElementById('xForm_StartingLine').value);
		SOAPClient.invoke(url, "Highlight", pl, true, callOrYAPPConverter_callBack);
	} catch(e) {
		debugAlert("callOrYAPPConverter: " + e.message);
	}
}

function callOrYAPPConverter_callBack(r) {
	try {
		document.getElementById('xForm_yappCode').value = '&nbsp;';
		document.getElementById('xForm_yappCodeRTF').innerHTML = '&nbsp;';
		document.getElementById('xForm_yappCode').value = r;
		document.getElementById('xForm_yappCodeRTF').innerHTML = r;
	} catch(e) {
		debugAlert("callOrYAPPConverter_callBack: " + e.message);
	}
	hideWait();
}

function callOrBabelCode() {
	displayRss(ContentHeader, loadLocalXmlDoc('menuBabelCode.xml'), loadLocalXslDoc('contentMenu.xsl'));
	displayRss(ContentArea, loadLocalXmlDoc('formBabelCode.xml'), loadLocalXslDoc('rssForms.xsl'));
}

function checkCodeGearUpdates(forceCheck) {
	date = new Date();
	updateInfo = getSubNode(nodeSettings, 'updateInfo');
	updateFound = false;

	if (forceCheck || (getItemValue(updateInfo, 'lastCheck') != date.toLocaleDateString()))
	{
		xmlHTTP = getXmlHttpDoc();
		doDownloadNews(xmlHTTP, "http://dn.codegear.com/updates/delphi/rss", checkCodeGearUpdatesCallBack, null);
	}
}

function checkCodeGearUpdatesCallBack(xmlDoc, params) {
	date = new Date();

	if (xmlDoc != null) {
		if (clientIsOnline && xmlDoc.documentElement.selectNodes("channel/item").length > 0) {
			getSubNode(updateInfo, 'lastCheck').text = date.toLocaleDateString();
			updateFound = true;
			cacheXml = getSubNode(updateInfo, 'cache');
			cacheXml.text = "";
			items = xmlDoc.getElementsByTagName("channel");
			for (var i = 0; i < items.length; i++)
			{
				cacheXml.appendChild(items[i]);
			}
		}
		savePersonalSettings();

		displayRss(ContentHeader, loadLocalXmlDoc('menuBdsUpdates.xml'), loadLocalXslDoc('contentMenu.xsl'));
		displayRss(ContentArea, xmlPersonal, loadLocalXslDoc('orBDSUpdates.xsl'));
	} else {
		debugAlert("could not load XML");
	}
}

function callOrCodeGearUpdates() {
	try {
		checkCodeGearUpdates(true);
	} catch(e) {
		debugAlert("callOrCodeGearUpdates: " + e.Message);
	}
}

function callOrPartnerLinks() {
	displayRss(ContentHeader, loadLocalXmlDoc('menuOnlineResources.xml'), loadLocalXslDoc('contentMenu.xsl'));
	displayRss(ContentArea, loadLocalXmlDoc('onlineResourcesPartner.xml'), loadLocalXslDoc('rssSummary.xsl'));
}

function orCopyFromClipboard(sourceElement) {
    try {
        sourceElement.value = window.clipboardData.getData('text');
    } catch(e) {
        debugAlert("orCopyFromClipboard: " + e.message);
    }
}

function orCopyToClipboard(sourceElement) {
    try {
        window.clipboardData.setData('text', sourceElement.value);
    } catch(e) {
        debugAlert("orCopyToClipboard: " + e.message);
    }
}
