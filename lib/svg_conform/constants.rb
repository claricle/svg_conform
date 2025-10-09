# frozen_string_literal: true

module SvgConform
  module Constants
    # SVG elements allowed in SVG 1.2 RFC (based on RFC 7996 and svgcheck)
    SVG_ELEMENTS = {
      "svg" => %w[version baseProfile width viewBox preserveAspectRatio snapshotTime
                  height id role break color-rendering fill-rule],
      "desc" => %w[id role shape-rendering text-rendering buffered-rendering
                   visibility],
      "title" => %w[id role shape-rendering text-rendering buffered-rendering
                    visibility],
      "path" => %w[d pathLength stroke-miterlimit id role fill style
                   transform font-size fill-rule],
      "rect" => %w[x y width height rx ry stroke-miterlimit
                   id role fill style transform fill-rule],
      "circle" => %w[cx cy r id role fill style transform fill-rule],
      "line" => %w[x1 y1 x2 y2 id role fill transform fill-rule],
      "ellipse" => %w[cx cy rx ry id role fill style transform fill-rule],
      "polyline" => %w[points id role fill transform fill-rule],
      "polygon" => %w[points id role fill style transform fill-rule],
      "solidColor" => %w[id role fill fill-rule],
      "textArea" => %w[x y width height auto id role fill transform fill-rule],
      "text" => %w[x y rotate id role fill style transform font-size fill-rule],
      "g" => %w[label class id role fill style transform fill-rule visibility],
      "defs" => %w[id role fill fill-rule],
      "use" => %w[x y href id role fill transform fill-rule],
      "a" => %w[id role fill transform fill-rule target],
      "tspan" => %w[x y id role fill fill-rule],
      "tbreak" => %w[id role],
    }.freeze

    # SVG properties with their allowed values
    SVG_PROPERTIES = {
      "about" => [],
      "base" => [],
      "baseProfile" => [],
      "d" => [],
      "break" => [],
      "class" => [],
      "content" => [],
      "cx" => ["<number>"],
      "cy" => ["<number>"],
      "datatype" => [],
      "height" => ["<number>"],
      "href" => [],
      "id" => [],
      "label" => [],
      "lang" => [],
      "pathLength" => [],
      "points" => [],
      "preserveAspectRatio" => [],
      "property" => [],
      "r" => ["<number>"],
      "rel" => [],
      "resource" => [],
      "rev" => [],
      "role" => [],
      "rotate" => [],
      "rx" => ["<number>"],
      "ry" => ["<number>"],
      "space" => [],
      "snapshotTime" => [],
      "transform" => [],
      "typeof" => [],
      "version" => [],
      "width" => ["<number>"],
      "viewBox" => ["<number>"],
      "x" => ["<number>"],
      "x1" => ["<number>"],
      "x2" => ["<number>"],
      "y" => ["<number>"],
      "y1" => ["<number>"],
      "y2" => ["<number>"],

      "stroke" => ["none", "<paint>"],
      "stroke-width" => [],
      "stroke-linecap" => %w[butt round square inherit],
      "stroke-linejoin" => %w[miter round bevel inherit],
      "stroke-miterlimit" => [],
      "stroke-dasharray" => [],
      "stroke-dashoffset" => [],
      "stroke-opacity" => [],
      "vector-effect" => %w[non-scaling-stroke none inherit],
      "viewport-fill" => ["none", "currentColor", "inherit", "<color>"],

      "display" => %w[inline block list-item run-in compact table inline-table
                      table-row-group table-header-group table-footer-group
                      table-row table-column-group table-column table-cell
                      table-caption none inherit],
      "viewport-fill-opacity" => [],
      "visibility" => %w[visible hidden collapse inherit],
      "image-rendering" => %w[auto optimizeSpeed optimizeQuality inherit],
      "color-rendering" => %w[auto optimizeSpeed optimizeQuality inherit],
      "shape-rendering" => %w[auto optimizeSpeed crispEdges geometricPrecision
                              inherit],
      "text-rendering" => %w[auto optimizeSpeed optimizeLegibility
                             geometricPrecision inherit],
      "buffered-rendering" => %w[auto dynamic static inherit],

      "solid-opacity" => [],
      "solid-color" => ["currentColor", "inherit", "<color>"],
      "color" => ["currentColor", "inherit", "<color>"],

      "stop-color" => ["currentColor", "inherit", "<color>"],
      "stop-opacity" => [],

      "line-increment" => [],
      "text-align" => %w[start end center inherit],
      "display-align" => %w[auto before center after inherit],

      "font-size" => [],
      "font-family" => %w[serif sans-serif monospace inherit],
      "font-weight" => %w[normal bold bolder lighter inherit 100 200 300 400
                          500 600 700 800 900],
      "font-style" => %w[normal italic oblique inherit],
      "font-variant" => %w[normal small-caps inherit],
      "direction" => %w[ltr rtl inherit],
      "unicode-bidi" => %w[normal embed bidi-override inherit],
      "text-anchor" => %w[start middle end inherit],
      "fill" => ["none", "inherit", "<color>"],
      "fill-rule" => %w[nonzero evenodd inherit],
      "fill-opacity" => [],

      "requiredFeatures" => [],
      "requiredFormats" => [],
      "requiredExtensions" => [],
      "requiredFonts" => [],
      "systemLanguage" => [],
    }.freeze

    # Basic types for validation
    BASIC_TYPES = {
      "<color>" => %w[black #ffffff #FFFFFF white #000000],
      "<paint>" => ["none", "currentColor", "inherit", "<color>"],
      "<integer>" => ["+"],
      "<number>" => ["+"],
    }.freeze

    # Default color for replacements
    COLOR_DEFAULT = "black"

    # Color threshold for grayscale conversion (from Python code)
    COLOR_THRESHOLD = 764

    # Style properties that can be promoted to attributes
    STYLE_PROPERTIES = %w[
      font-family font-weight font-style font-variant direction unicode-bidi
      text-anchor fill fill-rule stroke stroke-width font-size fill-opacity
      stroke-linecap stroke-opacity stroke-linejoin
    ].freeze

    # Elements allowed within other elements
    SVG_CHILD_ELEMENTS = %w[
      title path rect circle line ellipse polyline polygon solidColor
      textArea text g defs use a tspan desc
    ].freeze

    TEXT_CHILD_ELEMENTS = %w[desc title tspan text a].freeze

    ELEMENT_CHILDREN = {
      "svg" => SVG_CHILD_ELEMENTS,
      "desc" => ["text"],
      "title" => ["text"],
      "path" => %w[title desc],
      "rect" => %w[title desc],
      "circle" => %w[title desc],
      "line" => %w[title desc],
      "ellipse" => %w[title desc],
      "polyline" => %w[title desc],
      "polygon" => %w[title desc],
      "solidColor" => %w[title desc],
      "textArea" => TEXT_CHILD_ELEMENTS,
      "text" => TEXT_CHILD_ELEMENTS,
      "g" => SVG_CHILD_ELEMENTS,
      "defs" => SVG_CHILD_ELEMENTS,
      "use" => %w[title desc],
      "a" => SVG_CHILD_ELEMENTS,
      "tspan" => TEXT_CHILD_ELEMENTS + ["tbreak"],
    }.freeze

    # Allowed SVG namespaces
    SVG_NAMESPACES = [
      "http://www.w3.org/2000/svg",
    ].freeze

    # Allowed XML namespaces
    XMLNS_NAMESPACES = [
      "http://www.w3.org/2000/svg",
      "http://www.w3.org/1999/xlink",
      "http://www.w3.org/XML/1998/namespace",
    ].freeze

    # Color mapping for common color names to RFC-compliant colors
    COLOR_MAP = {
      "rgb(0,0,0)" => "black",
    }.freeze
  end
end
