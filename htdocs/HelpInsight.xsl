<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="html"/>

<xsl:template  match="para">
	<p>
	<xsl:apply-templates/>
	</p>
</xsl:template>

<xsl:template match="paramref">
	<xsl:value-of select="@name"/>
</xsl:template>

<xsl:template match="summary">
	<p>
	<xsl:apply-templates/>
	</p>
</xsl:template>

<xsl:template match="c">
	<tt><xsl:apply-templates/></tt>
</xsl:template>

<xsl:template match="code">
	<pre><xsl:apply-templates/></pre>
</xsl:template>

<xsl:template match="see">
	<a>
		<xsl:if test="@cref">
			<xsl:attribute name="href">
				helpinsight:/typelink:<xsl:value-of select="@cref" />
			</xsl:attribute>

			<xsl:if test="@DisplayName">
				<xsl:value-of select="@DisplayName" />
			</xsl:if>

			<xsl:if test="string(@DisplayName) = ''">
				<xsl:value-of select="@cref" />
			</xsl:if>
		</xsl:if>

		<xsl:if test="@langword">
			<xsl:attribute name="href">
				langword:<xsl:value-of select="@langword" />
			</xsl:attribute>

			<xsl:if test="@DisplayName">
				<xsl:value-of select="@DisplayName" />
			</xsl:if>

			<xsl:if test="string(@DisplayName) = ''">
				<xsl:value-of select="@langword" />
			</xsl:if>
		</xsl:if>
	</a>
</xsl:template>


<xsl:template match="exception">
	<DT>
		<I>
	<a>
		<xsl:attribute name="href">
			helpinsight:/typelink:<xsl:value-of select="@cref"/>
		</xsl:attribute>

		<xsl:if test="@DisplayName">
			<xsl:value-of select="@DisplayName" />
		</xsl:if>

		<xsl:if test="string(@DisplayName) = ''">
			<xsl:value-of select="@cref" />
		</xsl:if>
	</a>
		</I>
	</DT>
	<DD>
		<xsl:apply-templates/>
	</DD>
</xsl:template>

<xsl:template match="permission">
	<DT>
		<I>

	<a>
		<xsl:attribute name="href">
			helpinsight:/typelink:<xsl:value-of select="@cref"/>
		</xsl:attribute>

		<xsl:if test="@DisplayName">
			<xsl:value-of select="@DisplayName" />
		</xsl:if>

		<xsl:if test="string(@DisplayName) = ''">
			<xsl:value-of select="@cref" />
		</xsl:if>
	</a>

		</I>
	</DT>
	<DD>
		<xsl:apply-templates/>
	</DD>
</xsl:template>

<xsl:template match="param">
	<DT>
		<I><xsl:value-of select="@name"/></I>
	</DT>
	<DD>
		<xsl:apply-templates/>
	</DD>
</xsl:template>


<xsl:template match="/">

<html>
	<head>

		<link type='text/css' rel='Stylesheet' href='HelpInsight.css' />
		<title>
			<xsl:value-of select="member/@DisplayName"/>
		</title>
	</head>

<body>

<div name="main">
<table
	background="HelpInsightGradient.gif"
	border="0"
	width="100%"
	cellpadding="0"
	cellspacing="0">
	<tr>
		<td nowrap="true">
			<div class="maincaption">
				<xsl:value-of select="member/@DisplayName"/>
				<xsl:if test="member/source">
					-
		<a class="codelink">
			<xsl:attribute name="href">helpinsight:/filelink:<xsl:value-of select="member/source/@declaredIn"/>?<xsl:value-of select="member/source/@declaredOn"/></xsl:attribute>
			<xsl:value-of select="member/source/@declaredInShort"/> (<xsl:value-of select="member/source/@declaredOn"/>)</a>
				</xsl:if>
			</div>
		</td>
	</tr>
</table>

<xsl:apply-templates select="member/summary"/>

<xsl:if test="count(member/param) > 0">
	<H4>Parameters</H4>
	<P>
	<DL>
		<xsl:for-each select="member/param">
			<xsl:apply-templates select="."/>
		</xsl:for-each>
	</DL>
	</P>
</xsl:if>

<xsl:if test="count(member/returns) > 0">
	<H4>Returns</H4>
	<P>
	<DL>
		<xsl:apply-templates select="member/returns"/>
	</DL>
	</P>
</xsl:if>


<xsl:if test="count(member/exception) > 0">
	<H4>Exceptions</H4>
	<P>
	<DL>
		<xsl:for-each select="member/exception">
			<xsl:apply-templates select="."/>
		</xsl:for-each>
	</DL>
	</P>
</xsl:if>

<xsl:if test="count(member/permission) > 0">
	<H4>Permission</H4>
	<P>
	<DL>
		<xsl:for-each select="member/permission">
			<xsl:apply-templates select="."/>
		</xsl:for-each>
	</DL>
	</P>
</xsl:if>

<xsl:if test="member/remarks">
	<H4>Remarks</H4>
	<P>
	<DL>
		<xsl:for-each select="member/remarks">
			<xsl:apply-templates select="."/>
		</xsl:for-each>
	</DL>
	</P>
</xsl:if>

<xsl:if test="member/comments">
	<H4>Comments</H4>
	<P>
	<DL>
		<xsl:for-each select="member/comments">
			<xsl:apply-templates select="."/>
		</xsl:for-each>
	</DL>
	</P>
</xsl:if>


</div>

</body>
</html>




</xsl:template>

</xsl:stylesheet>


