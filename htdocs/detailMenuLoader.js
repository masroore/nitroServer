function contentMenuExpand(s) {
	var td = s;
	var d = td.getElementsByTagName("div").item(0);

	if (td.className == "contentMenuItem") td.className = "contentMenuItemHover";
	if (d.className == "contentMenuSubMenu") {d.className = "contentMenuSubMenuHover"} else {d.className = "contentMenuSubMenu2Hover"};
}
	
function contentMenuCollapse(s) {
	var td = s;
	var d = td.getElementsByTagName("div").item(0);

	if (td.className == "contentMenuItemHover") td.className = "contentMenuItem";
	if (d.className == "contentMenuSubMenuHover") {d.className = "contentMenuSubMenu"} else {d.className = "contentMenuSubMenu2"};
}
