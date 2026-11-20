class HtmlUtils {
  static String clean(String? raw) {
    if (raw == null || raw.isEmpty) return '';

    var text = raw;

    // 1. Decode entities first so encoded tags (&lt;p&gt;) become standard tags (<p>)
    text = _decodeEntities(text);

    // 1.1 Remove style, script, and xml blocks completely including content
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');

    // 2. Strip standard HTML tags (<p style="...">, <div>, <br/>, <a href="...">, etc.)
    text = text.replaceAll(RegExp(r'<[^>]+>', multiLine: true, caseSensitive: false), ' ');

    // 3. Strip any residual encoded tags like &lt;...&gt;
    text = text.replaceAll(RegExp(r'&lt;[^&]*&gt;', multiLine: true, caseSensitive: false), ' ');

    // 4. Second pass entity decode for entities revealed after tag stripping
    text = _decodeEntities(text);

    // 5. Final tag strip pass
    text = text.replaceAll(RegExp(r'<[^>]+>', multiLine: true, caseSensitive: false), ' ');

    // 6. Clean escaped slashes, carriage returns, and collapse multiple whitespace
    text = text.replaceAll(r'\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  static String _decodeEntities(String str) {
    return str
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&#8230;', '...')
        .replaceAll('&hellip;', '...');
  }
}
