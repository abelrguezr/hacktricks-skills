#!/usr/bin/env python3
"""
PDF YARA Rule Generator
Generates custom YARA rules based on PDF analysis findings
"""

import json
import sys
from datetime import datetime
from pathlib import Path


def generate_yara_rule(pdf_path: str, output_path: str = None, custom_strings: list = None):
    """
    Generate a YARA rule for PDF detection based on analysis.
    
    Args:
        pdf_path: Path to the PDF file to analyze
        output_path: Path to save the YARA rule (default: pdf_path + .yar)
        custom_strings: List of custom strings to include in the rule
    """
    
    pdf_path = Path(pdf_path)
    if not pdf_path.exists():
        print(f"Error: File not found: {pdf_path}")
        sys.exit(1)
    
    if output_path is None:
        output_path = str(pdf_path.with_suffix('.yar'))
    
    # Read PDF content
    try:
        with open(pdf_path, 'rb') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)
    
    # Check for various indicators
    indicators = {
        'pdf_magic': content[:4] == b'%PDF',
        'has_js': b'/JS' in content or b'/JavaScript' in content,
        'has_openaction': b'/OpenAction' in content,
        'has_aa': b'/AA' in content,
        'has_launch': b'/Launch' in content,
        'has_embedded': b'/EmbeddedFile' in content or b'/Filespec' in content,
        'has_uri': b'/URI' in content,
        'has_gotoe': b'/GoToE' in content,
        'has_richmedia': b'/RichMedia' in content,
        'has_flash': b'/Flash' in content,
        'has_3d': b'/3D' in content,
        'has_xfa': b'/XFA' in content,
        'has_acroform': b'/AcroForm' in content,
        'has_objstm': b'/ObjStm' in content,
        'polyglot_word': b'<w:WordDocument>' in content,
        'multiple_eof': content.count(b'%%EOF') > 1,
        'multiple_catalog': content.count(b'/Catalog') > 1,
    }
    
    # Build strings section
    strings = []
    strings.append('        $pdf_magic = { 25 50 44 46 }          // %PDF')
    
    if indicators['has_js']:
        strings.append('        $js        = "/JS" ascii nocase')
        strings.append('        $javascript = "/JavaScript" ascii nocase')
    
    if indicators['has_openaction']:
        strings.append('        $openact   = "/OpenAction" ascii nocase')
    
    if indicators['has_aa']:
        strings.append('        $aa        = "/AA" ascii nocase')
    
    if indicators['has_launch']:
        strings.append('        $launch    = "/Launch" ascii nocase')
    
    if indicators['has_embedded']:
        strings.append('        $embedded  = "/EmbeddedFile" ascii nocase')
        strings.append('        $filespec  = "/Filespec" ascii nocase')
    
    if indicators['has_uri']:
        strings.append('        $uri       = "/URI" ascii nocase')
    
    if indicators['has_gotoe']:
        strings.append('        $gotoe     = "/GoToE" ascii nocase')
    
    if indicators['has_richmedia']:
        strings.append('        $richmedia = "/RichMedia" ascii nocase')
    
    if indicators['has_flash']:
        strings.append('        $flash     = "/Flash" ascii nocase')
    
    if indicators['has_3d']:
        strings.append('        $d3        = "/3D" ascii nocase')
    
    if indicators['has_xfa']:
        strings.append('        $xfa       = "/XFA" ascii nocase')
    
    if indicators['has_acroform']:
        strings.append('        $acroform  = "/AcroForm" ascii nocase')
    
    if indicators['has_objstm']:
        strings.append('        $objstm    = "/ObjStm" ascii nocase')
    
    if indicators['polyglot_word']:
        strings.append('        $worddoc   = "<w:WordDocument>" ascii')
    
    # Add custom strings if provided
    if custom_strings:
        for i, s in enumerate(custom_strings):
            strings.append(f'        $custom{i}   = "{s}" ascii nocase')
    
    # Build condition
    conditions = []
    conditions.append('        $pdf_magic at 0')
    
    # Auto-exec conditions
    if indicators['has_aa'] and indicators['has_js']:
        conditions.append('        ( $aa and ($js or $javascript) )')
    
    if indicators['has_openaction'] and indicators['has_js']:
        conditions.append('        ( $openact and ($js or $javascript) )')
    
    if indicators['has_launch']:
        conditions.append('        $launch')
    
    if indicators['has_embedded']:
        conditions.append('        ($embedded or $filespec)')
    
    if indicators['polyglot_word']:
        conditions.append('        $worddoc')
    
    if indicators['multiple_eof']:
        conditions.append('        #%%EOF > 1')
    
    if indicators['multiple_catalog']:
        conditions.append('        #/Catalog > 1')
    
    # Build final condition
    if len(conditions) > 1:
        condition = '        ' + ' and (\n            ' + '\n            '.join(conditions[1:]) + '\n        )'
    else:
        condition = '        ' + conditions[0]
    
    # Generate rule name based on findings
    rule_name = 'Suspicious_PDF'
    if indicators['has_js']:
        rule_name += '_WithJS'
    if indicators['polyglot_word']:
        rule_name += '_Polyglot'
    if indicators['multiple_eof']:
        rule_name += '_Incremental'
    
    # Generate YARA rule
    yara_rule = f'''rule {rule_name} {{
    meta:
        description = "PDF detection rule generated from analysis of {pdf_path.name}"
        author      = "PDF Forensics Analysis"
        last_update = "{datetime.now().strftime('%Y-%m-%d')}"
        reference   = "Generated automatically"
    strings:
''' + '\n'.join(strings) + f'''
    condition:
{condition}
}}
'''
    
    # Write to file
    with open(output_path, 'w') as f:
        f.write(yara_rule)
    
    print(f"YARA rule generated: {output_path}")
    print(f"\nDetected indicators:")
    for indicator, found in indicators.items():
        if found:
            print(f"  - {indicator}: YES")
    
    return yara_rule


def main():
    if len(sys.argv) < 2:
        print("Usage: python generate-yara-rule.py <pdf-file> [output-file] [custom-string1] [custom-string2] ...")
        print("Example: python generate-yara-rule.py suspicious.pdf detection.yar powershell cmd.exe")
        sys.exit(1)
    
    pdf_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    custom_strings = sys.argv[3:] if len(sys.argv) > 3 else None
    
    generate_yara_rule(pdf_path, output_path, custom_strings)


if __name__ == '__main__':
    main()
