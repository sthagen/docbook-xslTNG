<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:db="http://docbook.org/ns/docbook"
                xmlns:f="http://docbook.org/ns/docbook/functions"
                xmlns:fp="http://docbook.org/ns/docbook/functions/private"
                xmlns:ghost="http://docbook.org/ns/docbook/ghost"
                xmlns:m="http://docbook.org/ns/docbook/modes"
                xmlns:mp="http://docbook.org/ns/docbook/modes/private"
                xmlns:t="http://docbook.org/ns/docbook/templates"
                xmlns:tp="http://docbook.org/ns/docbook/templates/private"
                xmlns:vp="http://docbook.org/ns/docbook/variables/private"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="#all"
                version="3.0">

<xsl:import href="../environment.xsl"/>  

<!-- ============================================================ -->

<xsl:key name="id" match="*" use="@xml:id"/>
<xsl:key name="linked-to" match="*" use="tokenize(@linkend|@linkends, '\s+')"/>
<xsl:key name="glossed" match="db:glossterm[not(parent::db:glossentry)]|db:firstterm"
         use="normalize-space((@baseform, string(.))[1])"/>

<xsl:variable name="vp:docbook-namespace" select="'http://docbook.org/ns/docbook'"/>
<xsl:variable name="vp:unify-table-titles" select="false()"/>

<!-- ============================================================ -->

<xsl:template match="/*" priority="100">
  <xsl:variable name="body" as="element()">
    <xsl:next-match/>
  </xsl:variable>

  <xsl:element name="{local-name($body)}"
               namespace="{namespace-uri($body)}">
    <xsl:copy-of select="$body/@*, $body/namespace-node()"/>
    <xsl:copy-of select="$body/node()"/>
    <!-- only copy top-level annotations -->
    <xsl:sequence select="$vp:external-annotations/*/db:annotation"/>
  </xsl:element>
</xsl:template>

<!-- ============================================================ -->
<!-- normalize content -->

<xsl:variable name="vp:external-bibliographies" as="xs:string*">
  <xsl:variable name="string-list" as="xs:string*">
    <xsl:sequence select="f:pi(/*, 'bibliography-collection')"/>
    <xsl:sequence select="$bibliography-collection"/>
  </xsl:variable>
  <xsl:sequence select="tokenize(normalize-space(string-join($string-list, ' ')), '\s+')"/>
</xsl:variable>

<xsl:variable name="vp:external-bibliography">
  <wrapper xmlns="http://docbook.org/ns/docbook">
    <xsl:for-each select="$vp:external-bibliographies">
      <xsl:try select="document(.)/*">
        <xsl:catch expand-text="yes">
          <xsl:message>Failed to load bibliography: {.}</xsl:message>
          <xsl:sequence select="()"/>
        </xsl:catch>
      </xsl:try>
    </xsl:for-each>
  </wrapper>
</xsl:variable>

<xsl:variable name="vp:external-annotations">
  <xsl:choose>
    <xsl:when test="$annotation-collection = ''">
      <xsl:sequence select="()"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:try select="document($annotation-collection)">
        <xsl:catch>
          <xsl:message>Failed to load $annotation.collection:</xsl:message>
          <xsl:message select="'    ' || $annotation-collection"/>
          <xsl:message select="'    ('||resolve-uri($annotation-collection)||')'"/>
          <xsl:sequence select="()"/>
        </xsl:catch>
      </xsl:try>
    </xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<xsl:template name="tp:normalize-movetitle">
  <xsl:copy>
    <xsl:copy-of select="@*"/>

    <xsl:choose>
      <xsl:when test="db:info">
        <xsl:apply-templates/>
      </xsl:when>
      <xsl:when test="db:title|db:subtitle|db:titleabbrev">
        <xsl:element name="info" namespace="{$vp:docbook-namespace}">
          <xsl:call-template name="tp:normalize-dbinfo">
            <xsl:with-param name="copynodes"
                            select="db:title|db:subtitle|db:titleabbrev"/>
          </xsl:call-template>
        </xsl:element>
        <xsl:apply-templates/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:copy>
</xsl:template>

<xsl:template match="db:title|db:subtitle|db:titleabbrev">
  <xsl:if test="parent::db:info
                |parent::db:biblioentry
                |parent::db:bibliomixed
                |parent::db:bibliomset
                |parent::db:biblioset">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:if>
</xsl:template>

<xsl:template match="db:bibliography|db:revhistory">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:bibliomixed|db:biblioentry">
  <xsl:choose>
    <xsl:when test="empty(node()) and not(@xml:id)">
      <!-- totally empty, no id? -->
      <xsl:message>
        <xsl:text>Error: </xsl:text>
        <xsl:text>empty </xsl:text>
        <xsl:value-of select="local-name(.)"/>
        <xsl:text> with no id.</xsl:text>
      </xsl:message>
    </xsl:when>

    <xsl:when test="empty(key('linked-to', @xml:id))
                    and ancestor::db:bibliography[contains-token(@role, 'auto')]">
      <!-- In an "auto" bibliography, discard unlinked entries -->
    </xsl:when>

    <xsl:when test="empty(node())">
      <!-- totally empty -->
      <xsl:variable name="id" select="@xml:id"/>
      <xsl:choose>
        <xsl:when test="$vp:external-bibliography/key('id', $id)">
          <xsl:apply-templates select="$vp:external-bibliography/key('id', $id)"
                              />
        </xsl:when>
        <xsl:otherwise>
          <xsl:message>
            <xsl:text>Error: </xsl:text>
            <xsl:text>$bibliography-collection doesn't contain </xsl:text>
            <xsl:value-of select="$id"/>
          </xsl:message>
          <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:text>???</xsl:text>
          </xsl:copy>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:copy>
        <xsl:copy-of select="@*"/>
        <xsl:apply-templates/>
      </xsl:copy>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="db:glossary">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:glossary[contains-token(@role, 'auto')]">
  <!-- Locate all the external glossaries -->
  <xsl:variable name="gloss-uris" as="xs:string*">
    <xsl:sequence select="f:pi(root(.)/*, 'glossary-collection')"/>
    <xsl:sequence select="$glossary-collection"/>
  </xsl:variable>

  <xsl:variable name="glossary-entries" as="element(db:glossentry)*">
    <xsl:sequence select="root(.)//db:glossary//db:glossentry"/>
    <xsl:for-each select="tokenize(normalize-space(string-join($gloss-uris, ' ')), '\s+')">
      <xsl:try select="document(.)/db:glossary//db:glossentry">
        <xsl:catch expand-text="yes">
          <xsl:message>Failed to load glossary: {.}</xsl:message>
          <xsl:sequence select="()"/>
        </xsl:catch>
      </xsl:try>
    </xsl:for-each>
  </xsl:variable>

  <xsl:variable name="this" select="root(.)"/>

  <xsl:variable name="unique-entries" as="element(db:glossentry)*">
    <xsl:iterate select="$glossary-entries">
      <xsl:param name="entries" as="element(db:glossentry)*" select="()"/>
      <xsl:on-completion select="$entries"/>
      <xsl:variable name="term" select="normalize-space(db:glossterm)"/>

      <xsl:choose>
        <xsl:when test="empty(key('glossed', $term, $this))">
          <!-- unreferenced, discard it -->
          <!--<xsl:message select="'Unreferenced:', $term"/>-->
          <xsl:next-iteration>
            <xsl:with-param name="entries" select="$entries"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:when test="$entries[db:glossterm = $term]">
          <!-- duplicate, discard it -->
          <!--<xsl:message select="'Duplicate:', $term"/>-->
          <xsl:next-iteration>
            <xsl:with-param name="entries" select="$entries"/>
          </xsl:next-iteration>
        </xsl:when>
        <xsl:otherwise>
          <!-- Ooh, we want this one! -->
          <!--<xsl:message select="'Keep:', $term"/>-->
          <xsl:next-iteration>
            <xsl:with-param name="entries" select="($entries, .)"/>
          </xsl:next-iteration>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:iterate>
  </xsl:variable>

  <xsl:variable name="glossary" as="element(db:glossary)">
    <xsl:call-template name="tp:normalize-generated-title">
      <xsl:with-param name="title-key" select="local-name(.)"/>
    </xsl:call-template>
  </xsl:variable>

  <glossary xmlns="http://docbook.org/ns/docbook">
    <xsl:sequence select="$glossary/@*, $glossary/node() except $glossary/db:glossentry"/>
    <xsl:sequence select="$unique-entries"/>
  </glossary>
</xsl:template>

<xsl:template match="db:index">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:setindex">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:abstract">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:legalnotice">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:dedication|db:acknowledgements">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:note">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:tip">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:caution">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:warning">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:danger">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:important">
  <xsl:call-template name="tp:normalize-generated-title">
    <xsl:with-param name="title-key" select="local-name(.)"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="db:dialogue|db:colophon|db:partintro|db:productionset
                     |db:calloutlist|db:orderedlist|db:itemizedlist
                     |db:qandaset|db:qandadiv|db:qandaentry
                     |db:bibliolist|db:glosslist|db:segmentedlist
                     |db:equation|db:poetry|db:blockquote|db:refentry
                     |db:screenshot|db:procedure|db:step|db:stepalternatives">
  <xsl:call-template name="tp:normalize-optional-title"/>
</xsl:template>

<!-- ============================================================ -->

<xsl:template name="tp:normalize-generated-title">
  <xsl:param name="title-key"/>

  <xsl:choose>
    <xsl:when test="db:title|db:info/db:title">
      <xsl:call-template name="tp:normalize-movetitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:copy>
        <xsl:copy-of select="@*"/>

        <xsl:choose>
          <xsl:when test="db:info">
            <xsl:element name="info" namespace="{$vp:docbook-namespace}">
              <xsl:copy-of select="db:info/@*"/>
              <xsl:element name="title" namespace="{$vp:docbook-namespace}">
                <xsl:apply-templates select="." mode="tp:normalized-title">
                  <xsl:with-param name="title-key" select="$title-key"/>
                </xsl:apply-templates>
              </xsl:element>
              <xsl:copy-of select="db:info/preceding-sibling::node()"/>
              <xsl:copy-of select="db:info/*"/>
            </xsl:element>

            <xsl:apply-templates select="db:info/following-sibling::node()"/>
          </xsl:when>

          <xsl:otherwise>
            <xsl:variable name="node-tree">
              <xsl:element name="title" namespace="{$vp:docbook-namespace}">
                <xsl:attribute name="ghost:title" select="'yes'"/>
                <xsl:apply-templates select="." mode="tp:normalized-title">
                  <xsl:with-param name="title-key" select="$title-key"/>
                </xsl:apply-templates>
              </xsl:element>
            </xsl:variable>

            <xsl:element name="info" namespace="{$vp:docbook-namespace}">
              <xsl:call-template name="tp:normalize-dbinfo">
                <xsl:with-param name="copynodes" select="$node-tree/*"/>
              </xsl:call-template>
            </xsl:element>
            <xsl:apply-templates/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:copy>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="*" mode="tp:normalized-title">
  <xsl:param name="title-key"/>
  <xsl:apply-templates select="." mode="m:gentext">
    <xsl:with-param name="group" select="'title-generated'"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="db:info">
  <xsl:copy>
    <xsl:copy-of select="@*"/>
    <xsl:if test="not(db:title)">
      <xsl:copy-of select="preceding-sibling::db:title"/>
    </xsl:if>
    <xsl:if test="not(db:subtitle)">
      <xsl:copy-of select="preceding-sibling::db:subtitle"/>
    </xsl:if>
    <xsl:call-template name="tp:normalize-dbinfo"/>
  </xsl:copy>
</xsl:template>

<!-- ============================================================ -->

<xsl:template name="tp:normalize-optional-title">
  <xsl:choose>
    <xsl:when test="db:title|db:info/db:title">
      <xsl:call-template name="tp:normalize-movetitle"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:copy>
        <xsl:copy-of select="@*"/>

        <xsl:choose>
          <xsl:when test="db:info">
            <xsl:element name="info" namespace="{$vp:docbook-namespace}">
              <xsl:copy-of select="db:info/@*"/>
              <xsl:copy-of select="db:info/preceding-sibling::node()"/>
              <xsl:copy-of select="db:info/*"/>
            </xsl:element>

            <xsl:apply-templates select="db:info/following-sibling::node()"
                                />
          </xsl:when>

          <xsl:otherwise>
            <xsl:element name="info" namespace="{$vp:docbook-namespace}">
              <xsl:call-template name="tp:normalize-dbinfo"/>
            </xsl:element>
            <xsl:apply-templates/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:copy>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ============================================================ -->

<xsl:template name="tp:normalize-dbinfo">
  <xsl:param name="copynodes"/>

  <xsl:for-each select="$copynodes">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:for-each>

  <xsl:if test="self::db:info">
    <xsl:apply-templates/>
  </xsl:if>
</xsl:template>

<xsl:template match="db:inlinemediaobject
                     [(parent::db:programlisting
                       or parent::db:screen
                       or parent::db:literallayout
                       or parent::db:address
                       or parent::db:funcsynopsisinfo)
                     and db:imageobject
                     and db:imageobject/db:imagedata[@format='linespecific']]">
  <xsl:variable name="data"
                select="(db:imageobject
                         /db:imagedata[@format='linespecific'])[1]"/>
  <xsl:choose>
    <xsl:when test="$data/@entityref">
      <xsl:value-of select="unparsed-text(unparsed-entity-uri($data/@entityref))"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of
          select="unparsed-text(resolve-uri($data/@fileref, base-uri(.)))"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="db:textobject
                     [parent::db:programlisting
                      or parent::db:screen
                      or parent::db:literallayout
                      or parent::db:address
                      or parent::db:funcsynopsisinfo]">
  <xsl:choose>
    <xsl:when test="db:textdata/@entityref">
      <xsl:value-of select="unparsed-text(unparsed-entity-uri(db:textdata/@entityref))"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="unparsed-text(resolve-uri(db:textdata/@fileref, base-uri(.)))"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="*">
  <xsl:choose>
    <xsl:when test="db:title|db:subtitle|db:titleabbrev|db:info/db:title">
      <xsl:choose>
        <xsl:when test="parent::db:biblioentry
                        |parent::db:bibliomixed
                        |parent::db:bibliomset
                        |parent::db:biblioset">
          <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
          </xsl:copy>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="tp:normalize-movetitle"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:copy>
        <xsl:copy-of select="@*"/>
        <xsl:apply-templates/>
      </xsl:copy>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="comment()|processing-instruction()|text()|attribute()">
  <xsl:copy/>
</xsl:template>

<!-- ============================================================ -->
<!-- copy external glossary -->

<xsl:template match="db:glossdiv" mode="mp:copy-external-glossary">
  <xsl:param name="terms"/>
  <xsl:param name="divs"/>

  <xsl:variable name="entries" as="element()*">
    <xsl:apply-templates select="db:glossentry" mode="mp:copy-external-glossary">
      <xsl:with-param name="terms" select="$terms"/>
      <xsl:with-param name="divs" select="$divs"/>
    </xsl:apply-templates>
  </xsl:variable>

  <xsl:if test="$entries">
    <xsl:choose>
      <xsl:when test="$divs">
        <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:copy-of select="db:info"/>
          <xsl:copy-of select="$entries"/>
        </xsl:copy>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="$entries"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>
</xsl:template>

<xsl:template match="db:glossentry" mode="mp:copy-external-glossary">
  <xsl:param name="terms"/>
  <xsl:param name="divs"/>

  <xsl:variable name="include"
                select="for $dterm in $terms
                           return
                              for $gterm in db:glossterm
                                 return
                                    if (string($dterm) = string($gterm)
                                        or $dterm/@baseform = string($gterm))
                                    then 'x'
                                    else ()"/>

  <xsl:if test="$include != ''">
    <xsl:copy-of select="."/>
  </xsl:if>
</xsl:template>

<xsl:template match="*" mode="mp:copy-external-glossary">
  <xsl:param name="terms"/>
  <xsl:param name="divs"/>

  <xsl:copy>
    <xsl:copy-of select="@*"/>
    <xsl:apply-templates mode="mp:copy-external-glossary">
      <xsl:with-param name="terms" select="$terms"/>
      <xsl:with-param name="divs" select="$divs"/>
    </xsl:apply-templates>
  </xsl:copy>
</xsl:template>

<!-- ============================================================ -->

<xsl:template match="db:informaltable[db:tr]
                     |db:table[db:tr]"
              xmlns="http://docbook.org/ns/docbook">
  <xsl:copy>
    <xsl:apply-templates select="@*"/>

    <xsl:for-each-group select="*" group-by="node-name(.)">
      <xsl:choose>
        <xsl:when test="current-group()[1]/self::db:tr">
          <tbody>
            <xsl:sequence select="current-group()"/>
          </tbody>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="current-group()"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each-group>
  </xsl:copy>
</xsl:template>

<!-- If we're unifying titles, turn the caption into a title. -->
<xsl:template match="db:table/db:caption"
              xmlns="http://docbook.org/ns/docbook">
  <xsl:choose>
    <xsl:when test="$vp:unify-table-titles">
      <info>
        <title>
          <xsl:apply-templates select="@*,node()"/>
        </title>
      </info>
    </xsl:when>
    <xsl:otherwise>
      <xsl:next-match/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>
