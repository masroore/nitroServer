var xmlRssCache;
var rssFeedList = new Array();
var cacheNotificationNode;
var rssTimeout;

function registerRssLinks() {
	xmlRssCache = loadXmlDocSafe(clientAppDataFolder + '\\newsCache.xml');

	persistentMenuCalls.push('{DDDD860A-11C3-41F4-9DC9-E575DCA86088}', callRssRead);
	persistentMenuCalls.push('{49996494-932A-4834-B9F2-5224C9A5B6A7}', callRssViewSummary);
}

function displayRss(docNode, xmlSource, xslSource)
{
	try
	{
		docNode.innerHTML = xmlSource.transformNode(xslSource);
		docNode.style.visibility = 'visible';
	} catch(e) {
		docNode.style.visibility = 'hidden';
		debugAlert('displayRss: ' + e.message + ' ' + xmlSource.url + ' ' + xslSource.url);
	}
}

function callRssRead() {
	displayRss(ContentHeader, loadLocalXmlDoc('menuRSSFeeds.xml'), loadLocalXslDoc('contentMenu.xsl'));
	displayDefaultRss();
}

function callRssViewSummary() {
	displayRss(ContentHeader, loadLocalXmlDoc('menuSummary.xml'), loadLocalXslDoc('contentMenu.xsl'));
	displayRss(ContentArea, xmlRssCache, loadLocalXslDoc('rssSummary.xsl'));
}

function callRssDownloadAll() {
	var feedsDoc;
	var feeds;
	var feed;

  setClientIsOnline(true);
	try {
		feedsDoc = loadLocalXmlDoc('menuRSSFeeds.xml');
		feeds = feedsDoc.documentElement.selectNodes('.//item');
		for (var i = 0; i < feeds.length; i++) {
			feed = feeds[i];
			URI = getSubNode(feed, 'link').text;
			if (URI.indexOf("://") >= 0) {
				if(feed.getAttributeNode("localcontent") == null) {
					rssFeedList.push(feed);
				}
			}
		}
	} catch(e) {
		debugAlert("callRssDownloadAll: " + e.message);
	}
	cacheNotificationNode = getNotification(true);
	cacheNotificationNode.text = getLangString("initDownload");
	showWait();
	popNextRssFeed();
}

function popNextRssFeedCallBack(xmlDoc, params) {
	var items;
	var cacheXml, date, feed;
	
	try {
		cacheXml = params[0];
		date = params[1];
		feed = params[2];
	
		if (xmlDoc != null) {
			cacheXml.text = "";
			items = xmlDoc.getElementsByTagName("channel");
			for (var j = 0; j < items.length; j++) {
				cacheXml.appendChild(items[j]);
			}
			setAttrValue(cacheXml, "lastLoad", date.toLocaleDateString());
			setAttrValue(cacheXml, "selectOnly", getItemValue(feed, "selectOnly"));
			saveRssCache();
		} else {
			debugAlert(getLangString("notLoaded") + " " + getItemValue(feed, "title"));
		}
	} finally {
		rssTimeout = window.setTimeout("popNextRssFeed();", 50);
	}
}

function popNextRssFeed() {
	var feed;
	var URI;
	var xmlHTTP;
	var cacheXml;
	var date = new Date();

	if ((rssFeedList.length > 0) && (clientIsOnline)) {
		feed = rssFeedList.pop();
		xmlHTTP = getXmlHttpDoc();

		URI = getSubNode(feed, 'link').text;

		cacheXml = getSubNodeEx(xmlRssCache.documentElement, "rss", "link", URI);
		try {
			cacheNotificationNode.text = getLangString("loading") + " " + getItemValue(feed, "title") + " (" + rssFeedList.length + " " + getLangString("feedsLeft") + ")";
			displayNotification();
			doDownloadNews(xmlHTTP, URI, popNextRssFeedCallBack, [cacheXml, date, feed]);
		} catch(e) {
			popNextRssFeedCallBack(null, [cacheXml, date, feed]);
		}
	} else {
		while (rssFeedList.length > 0) {
			rssFeedList.pop();
		}
		saveRssCache();
		menuGuidCall('');
		removeNotification(cacheNotificationNode);
		hideWait();
	}
}

function determineDefaultFeed()
{
	var item;
	var xmlDefault;

	// check personal settings
	item = getSubNode(nodeSettings, 'defaultFeed');
	if (getItemValue(item, 'link') == '')
	{
		xmlDefault = loadLocalXmlDoc('menuRSSFeeds.xml');
		item = xmlDefault.selectSingleNode('.//item[@default]');
		if (item == null)
		{
			item = xmlDefault.selectSingleNode('.//item');
		}
	}
	return item;
}


function doDownloadNewsDone(xmlHTTP, callBack, params, async) {
	var xmlDoc;

	hideWait();	
	if (xmlHTTP.status != 200)
	{
		if (async) {
			callBack(null, params);
		}
		return null;
	}

	try {
		xmlDoc = getXmlDoc();
		xmlDoc.load(xmlHTTP.responseStream);
		if (xmlDoc.parseError.errorCode == 0)
		{
			if (isAtomFeed(xmlDoc)) {
				xmlDoc = convertAtom2RSS(xmlDoc);
			} else if (isRDFFeed(xmlDoc)) {
				xmlDoc = convertRDF2RSS(xmlDoc);
			}
			if (async) {
				callBack(xmlDoc, params);
			}
			return xmlDoc;
		} else {
			if (async) {
				callBack(null, params);
			}
			return null;
		}
	} catch(e) {
		debugAlert("JS Error: " + e.message);
		if (async) {
			callBack(null, params);
		}
		return null;
	}
}

function doDownloadNews(xmlHTTP, linkUrl, callBack, params)
{
	var lxmlHttp;
	
	if (callBack) {
		async = true;
	} else {
		async = false;
	}

	if (!clientIsOnline) {
		if (async) {
			callBack(null, params);
		}
		return null;
	}

	try {
		lResolve = 20 * 1000;    // Timeout values are in milli-seconds
		lConnect = 30 * 1000;
		lSend = 30 * 1000;
		lReceive = 30 * 1000;
		xmlHTTP.setTimeouts(lResolve, lConnect, lSend, lReceive);
		if (clientUsesProxy & clientProxyString != "")
		{
			xmlHTTP.setProxy(2, clientProxyString);
		}
		xmlHTTP.open("GET", linkUrl, async);
		if (async) {
			xmlHTTP.onreadystatechange = function() 
			{
				if(xmlHTTP.readyState == 4) {
					doDownloadNewsDone(xmlHTTP, callBack, params, async);
				}
			}
		}
		if (clientProxyUser != "" && clientProxyPassword != "")
		{
			xmlHTTP.setProxyCredentials(clientProxyUser, clientProxyPassword);
		}
		xmlHTTP.setRequestHeader("User-Agent", clientUserAgentString);
	} catch(e) {
		debugAlert("doDownloadNews (1): " + e.message);
		setClientIsOnline(false);
		return null;
	}
	try {
		showWait();
		xmlHTTP.send();
	} catch(e) {
		hideWait();
		debugAlert("doDownloadNews (2): " + e.message);
		if (e.number == -2147012889) {
			setClientIsOnline(false);
		}
		if (async) {
			callBack(null, params);
		}
		return null;
	}
	if (!async) {
		return doDownloadNewsDone(xmlHTTP, callBack, params, async);
	}
}

function doGetNewsCallBack(xmlDoc, params) {
	var localContent, cacheXml, date, isLocal;
	localContent = params[0];
	cacheXml = params[1];
	date = params[2];
	isLocal = params[3];
	
	if (xmlDoc == null)
	{
		return null;
	}
	// quick'n dirty remove off all subnodes
	cacheXml.text = "";
	items = xmlDoc.getElementsByTagName("channel");
	for (var i = 0; i < items.length; i++)
	{
		cacheXml.appendChild(items[i]);
	}

	if (!isLocal)
	{
		setAttrValue(cacheXml, "lastLoad", date.toLocaleDateString());
		saveRssCache();
	}

	rssDoc = getXmlDoc();
	rssDoc.appendChild(cacheXml.cloneNode(true));
	displayThisRss(rssDoc);
}

function doGetNews(localContent, cacheXml, date)
{
	var xmlHTTP;
	var xmlDoc;

	try
	{
		xmlHTTP = getXmlHttpDoc();
	} catch(e) {
		return null;
	}

	if (getItemValue(cacheXml, "@link").indexOf("://") >= 0)
	{

		isLocal = false;
		try
		{
			if(localContent == null)
			{
				xmlDoc = doDownloadNews(xmlHTTP, getItemValue(cacheXml, "@link"), doGetNewsCallBack, [localContent, cacheXml, date, false]);
				return null;
			} else {
				xmlDoc = getXmlDoc();
				xmlDoc.load(wpPath + getItemValue(cacheXml, "@link"));
			}
		} catch(e) {
			return null;
		}
	} else {
		isLocal = true;
		xmlDoc = getXmlDoc();
		xmlDoc.load(wpPath + getItemValue(cacheXml, "@link"));
		if (xmlDoc.parseError.errorCode != 0) {
			xmlDoc.load(getItemValue(cacheXml, "@link"));
		}
	}

	doGetNewsCallBack(XmlDoc, [localContent, cacheXml, date, true]);

	return null;
}

function getFeed(feedDataNode)
{
	var date;
	var downloadNews;
	var rssDoc;

	downloadNews = false;
	date = new Date();

	// check cached feed data
	if (getItemValue(feedDataNode, "reload") == "1")
	{
		downloadNews = true;
		feedDataNode.removeChild(getSubNode(feedDataNode, "reload"));
	}

	URI = getItemValue(feedDataNode, "link");
	currentFeed = URI;
	cacheXml = getSubNodeEx(xmlRssCache.documentElement, "rss", "link", URI);
	setAttrValue(cacheXml, "selectOnly", getItemValue(feedDataNode, "selectOnly"));
	if (getItemValue(cacheXml, "@lastLoad") != date.toLocaleDateString())
	{
		downloadNews = true;
	}

	if (downloadNews)
	{
		doGetNews(feedDataNode.getAttributeNode("localcontent"), cacheXml, date);
	} else {
		rssDoc = getXmlDoc();
		rssDoc.appendChild(cacheXml.cloneNode(true));
		displayThisRss(rssDoc);
	}
	return null;
}

function saveSettings(reload, newFeedUrl, selectOnly)
{
	var defaultFeed;

	defaultFeed = getSubNode(nodeSettings, 'defaultFeed');
	getSubNode(defaultFeed, 'link').text = newFeedUrl;
	getSubNode(defaultFeed, 'selectOnly').text = selectOnly;
	getSubNode(defaultFeed, 'reload').text = reload;
}

function displayThisRss(rssDocument)
{
	var blogTitle = document.getElementById("blogTitle");
	displayRss(blogTitle, rssDocument, loadLocalXslDoc('blogTitle.xsl'));
	displayRss(ContentArea, rssDocument, loadLocalXslDoc('rssFeeds.xsl'));
}

function displayDefaultRss()
{
	getFeed(determineDefaultFeed(xmlPersonal));
}

function rssFeedSelected(reload, selectOnly, newFeedUrl)
{
	try {
		saveSettings(reload, newFeedUrl, selectOnly);
		displayDefaultRss();
		savePersonalSettings();
	} catch(e) {
		debugAlert('rssFeedSelected: ' + e.message);
	}
}

function callRssClearCache()
{
	var rootNode;
	var nodesCache;

	rootNode = xmlRssCache.documentElement;
	nodesCache = rootNode.selectNodes('rss');
	for (var i = 0; i < nodesCache.length; i++)
	{
		rootNode.removeChild(nodesCache.item(i));
	}
	
	saveRssCache();
	menuGuidCall('');
}

function saveRssCache()
{
	var settingsFile;

	settingsFile = clientAppDataFolder + '\\newsCache.xml';
	xmlRssCache.save(settingsFile);
}

function isAtomFeed(xmlDoc) {
	return xmlDoc.documentElement.selectNodes("entry").length > 0;
}

function convertAtom2RSS(xmlDoc) {
    var newDoc;
    var entries;
    var entry;
    var channel;
    var item;
    var dummy;

    newDoc = getXmlDoc();
    newDoc.loadXML('<rss />');
    channel = getSubNode(newDoc.documentElement, "channel");
    getSubNode(channel, "title").text = getSubNode(xmlDoc.documentElement, "title").text;
    getSubNode(channel, "link").text = getSubNode(xmlDoc.documentElement, 'link[@rel="alternate"]/@href').text;
    entries = xmlDoc.documentElement.selectNodes("entry");
    for (var i = 0; i < entries.length; i++) {
        entry = entries[i];
        item = channel.appendChild(newDoc.createNode(1, "item", ""));
        getSubNode(item, "title").text = getSubNode(entry, "title").text;
        getSubNode(item, "link").text = getSubNode(entry, 'link[@rel="alternate"]/@href').text;
        getSubNode(item, "pubDate").text = getSubNode(entry, "issued").text;
        getSubNode(item, "guid").text = getSubNode(entry, "id").text;
        dummy = entry.selectSingleNode("content | summary");
        if (dummy) {
            getSubNode(item, "description").appendChild(dummy);
        }
    }

    return newDoc;
}

function isRDFFeed(xmlDoc) {
	return xmlDoc.documentElement.selectNodes("item").length > 0;
}

function convertRDF2RSS(xmlDoc) {
    var newDoc;
    var entries;
    var entry;
    var channel;
    var item;
    var dummy;

    newDoc = getXmlDoc();
    newDoc.loadXML('<rss />');
    channel = getSubNode(newDoc.documentElement, "channel");
    getSubNode(channel, "title").text = getSubNode(xmlDoc.documentElement, "channel/title").text;
    getSubNode(channel, "link").text = getSubNode(xmlDoc.documentElement, 'channel/link').text;
    entries = xmlDoc.documentElement.selectNodes("item");
    for (var i = 0; i < entries.length; i++) {
        entry = entries[i];
        item = channel.appendChild(newDoc.createNode(1, "item", ""));
        getSubNode(item, "title").text = getSubNode(entry, "title").text;
        getSubNode(item, "link").text = getSubNode(entry, 'link').text;
        getSubNode(item, "pubDate").text = getSubNode(entry, "date").text;
        getSubNode(item, "guid").text = "";
        dummy = entry.selectSingleNode("description");
        if (dummy) {
            getSubNode(item, "description").appendChild(dummy);
        }
    }

    return newDoc;
}