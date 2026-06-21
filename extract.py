import re
with open('/tmp/old_prayer_history.dart', 'r') as f:
    text = f.read()

# find _buildNamazHistory
start1 = text.find('Widget _buildNamazHistory')
end1 = text.find('Widget _buildNafilSection')
if start1 != -1 and end1 != -1:
    history_code = text[start1:end1]
else:
    history_code = 'NOT FOUND'

start2 = text.find('Widget _buildNafilSection')
end2 = text.find('Widget _buildSectionLabel(String text)')
if start2 != -1 and end2 != -1:
    nafil_code = text[start2:end2]
else:
    nafil_code = 'NOT FOUND'

with open('extracted_methods.txt', 'w') as f:
    f.write(history_code)
    f.write(nafil_code)
