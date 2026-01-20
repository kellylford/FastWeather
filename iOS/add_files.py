#!/usr/bin/env python3
import re

# Read project file
with open('FastWeather.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# IDs for new files
files = {
    'HistoricalWeather': ('A1000HIST1', 'A1000HISTB1', 'Models', 'A10000006'),
    'HistoricalWeatherCache': ('A1000HIST2', 'A1000HISTB2', 'Services', 'A1000000A'),
    'HistoricalWeatherView': ('A1000HIST3', 'A1000HISTB3', 'Views', 'A10000010')
}

# Add PBXBuildFile entries
build_section = re.search(r'(\/\* Begin PBXBuildFile section \*\/)', content)
if build_section:
    insert_pos = build_section.end()
    entries = '\n'
    for name, (file_id, build_id, _, _) in files.items():
        entries += f'\t\t{build_id} /* {name}.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {name}.swift */; }};\n'
    content = content[:insert_pos] + entries + content[insert_pos:]

# Add PBXFileReference entries
file_section = re.search(r'(\/\* Begin PBXFileReference section \*\/)', content)
if file_section:
    insert_pos = file_section.end()
    entries = '\n'
    for name, (file_id, _, _, _) in files.items():
        entries += f'\t\t{file_id} /* {name}.swift */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = {name}.swift; sourceTree = "<group>"; }};\n'
    content = content[:insert_pos] + entries + content[insert_pos:]

# Add to group children (Models, Services, Views)
for name, (file_id, _, group_name, anchor_id) in files.items():
    # Find the group and add after the anchor file
    pattern = rf'({anchor_id} \/\* \w+\.swift \*\/,)'
    match = re.search(pattern, content)
    if match:
        insert_pos = match.end()
        content = content[:insert_pos] + f'\n\t\t\t\t{file_id} /* {name}.swift */,' + content[insert_pos:]

# Add to PBXSourcesBuildPhase
sources_section = re.search(r'(A1000001F \/\* SettingsView\.swift in Sources \*\/,)', content)
if sources_section:
    insert_pos = sources_section.end()
    entries = ''
    for name, (_, build_id, _, _) in files.items():
        entries += f'\n\t\t\t\t{build_id} /* {name}.swift in Sources */,'
    content = content[:insert_pos] + entries + content[insert_pos:]

# Write back
with open('FastWeather.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ Successfully added files to Xcode project:")
for name in files:
    print(f"   - {name}.swift")
