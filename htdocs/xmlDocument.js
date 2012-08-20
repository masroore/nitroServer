function getItemValue(item, tag)
{
	var valueItem;
	
	if (item != null)
	{
		valueItem = item.selectSingleNode(tag);
		if (valueItem != null)
		{
			return valueItem.text;
		} else {
			return '';
		}
	} else {
		return '';
	}
}

function getXmlDoc()
{
	var xmlDoc;
	
	xmlDoc = new ActiveXObject("MSXML2.DOMDocument");
	xmlDoc.async = false;
	return xmlDoc;
}

function getXmlHttpDoc()
{
	var xmlDoc = null;
	var success;
	success = false;

	try {
		try {
			xmlDoc = new ActiveXObject('Msxml2.ServerXMLHTTP.7.0');
			if (xmlDoc.readyState == 0) ;
			success = true;
		} catch(e) {
			xmlDoc = null;
		}

		if (!success) {
			try {
				xmlDoc = new ActiveXObject('Msxml2.ServerXMLHTTP.6.0');
				if (xmlDoc.readyState == 0) ;
				success = true;
			} catch(e) {
				xmlDoc = null;
			}
		}
		
		if (!success) {
			try {
				xmlDoc = new ActiveXObject('Msxml2.ServerXMLHTTP.5.0');
				if (xmlDoc.readyState == 0) ;
				success = true;
			} catch(e) {
				xmlDoc = null;
			}
		}
		
		if (!success) {
			try {
				xmlDoc = new ActiveXObject('Msxml2.ServerXMLHTTP.4.0');
				if (xmlDoc.readyState == 0) ;
				success = true;
			} catch(e) {
				xmlDoc = null;
			}
		}
		
		if (!success) {
			try {
				xmlDoc = new ActiveXObject('Msxml2.ServerXMLHTTP');
				if (xmlDoc.readyState == 0) ;
				success = true;
			} catch(e) {
				xmlDoc = null;
			}
		}
		
		if (!success) {
			throw new createException(3, getLangString("xmlVersion"));
		}
	} catch(e) {
		debugAlert(getLangString("xmlVersion"));
	}
	
	return xmlDoc;
}

function loadXmlDoc(fileName)
{
	var xmlDoc;

	xmlDoc = getXmlDoc();
	xmlDoc.load(fileName);
	return xmlDoc;
}

function loadXmlDocSafe(fileName)
{
	var xmlDoc;

	xmlDoc = loadXmlDoc(fileName);
	if (xmlDoc.parseError.errorCode != 0)
	{
		xmlDoc.loadXML('<xml />');
	}
	return xmlDoc;
}

function getSubNode(xmlNode, nodeName)
{
	var subNode;

	subNode = xmlNode.selectSingleNode(nodeName);
	if (subNode == null)
	{
		subNode = xmlNode.appendChild(xmlNode.ownerDocument.createNode(1, nodeName, ''));
	}
	return subNode;
}

function getSubNodeEx(xmlNode, nodeName, attrName, attrValue)
{
	var subNode;
	var attr;
	var XSL;

	XSL = nodeName + '[@' + attrName + '="' + attrValue + '"]';
	subNode = xmlNode.selectSingleNode(XSL);
	if (subNode == null)
	{
		subNode = xmlNode.appendChild(xmlNode.ownerDocument.createNode(1, nodeName, ''));
		attr = xmlNode.ownerDocument.createNode(2, attrName, '');
		attr.text = attrValue;
		subNode.attributes.setNamedItem(attr);
	}
	return subNode;
}

function setAttrValue(xmlNode, attrName, attrValue)
{
	var attr;

	attr = xmlNode.ownerDocument.createNode(2, attrName, '');
	attr.text = attrValue;
	xmlNode.attributes.setNamedItem(attr);
}

function loadLocalXmlDoc(fileName)
{
	var xmlFile;

	xmlFile = xmlPath + fileName;
	return loadXmlDoc(xmlFile);
}

function loadLocalXslDoc(fileName)
{
	var xslFile;

	xslFile = xslPath + fileName;
	return loadXmlDoc(xslFile);
}

