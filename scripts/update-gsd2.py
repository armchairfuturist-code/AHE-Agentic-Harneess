
import base64, zlib, re

# Decode the GSD2 PowerShell block
encoded = "eJyVVV1P20AQfKzEr1illkhandvQh9JIlqDhQ6kKRCSIB6DRYa+dA3vPuruQUOC/V3c2cRwDonmJ5Z2b2V2PxxsbAAAfgTEGh6O9LTiSEaZwlkfcoL1b1ndTLWFW3LW4L7nY1JBZsPZvtCSYCzMFM0XQPMOiAqnQxhF4iY4csx5yM4UAWh7SXe9stH86PD05GPzev/QTHX1IkMzlCmvLnT5XwiDry1QqaEHRnKCkaLhE+34LSojn/rQ/oFi680bdw4O7qvcCAey0O8tCLBXycAptLwNB4BHOC1xn5bRjuOYaBxEE4GW+iGo1EUP7uc4ybsIpbP5p+586LFQy5sLb7MDDKsORxaC+6F7BU10lTJHTsd2mEyKeYVOqAi3V+krGu4MeWNVSrkb1uqJCriXZ1QbQ9miWpsAIrXiChIobIakvKRaJjwuj+E8Z3ftI/DrFiZkKurVHmX0E7zy7FJxgHEtlOmsbMAsIoPut+/X7VnP0F5hDSQYX5lxQJOcj8ReL6R3Nu/DrG8kMBLDd/fE+ec2zPBWUDLnimfYzvpgYeYtkHVRyde9xW4q534O4GI46s+0kdnJ9Q2G5mqnblLXp3NY4bVG0frJlpfeaCBW7VB5owGrLdExmkUDlPHFuJjJ7qBIhedfNWV1ZVc8Rm2YC4x6fjTex0RHxSohgEM0rG87IrMeO+yUz4HtUygjO9TZ+GAbHqEv6Q6VOVAyY7+0pFeo/VzJOxGh0n7xJvtF8th5ljKvtbVUGUunAWwPczOF7lcbWlmuUGt4hNEbvdfbZsfyGOepoPpTW0tKG5A98NoVl9+XMzKdMjXLRI8a0TmahSHqapwnwFTj2tpfFFv9JJA0EMsZRcDX52konnNVM1fhhCcIXahVwi+IPn+X9K3Ic4x64E3epC+oN/4BoPYI5A==" 
gsd2_block = zlib.decompress(base64.b64decode(encoded)).decode()

# Fix the path escaping issue in the PowerShell block
gsd2_block = gsd2_block.replace(r'\.gsd\agent\models.json', r'\.gsd\agent\models.json')

path = r'C:\Users\Administrator\Documents\Projects\AHE-Agentic-Harness\scripts\update-crofai-models.ps1'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

original = content

# Find insertion point
marker = 'Write-Color "\u2713 settings.json updated"'
idx = content.find(marker)
if idx > 0:
    end_of_line = content.find('\n', idx)
    before = content[:end_of_line + 1]
    after = content[end_of_line + 1:]
    content = before + gsd2_block + after
    print('Inserted GSD2 update block')
else:
    print('WARNING: Could not find marker, last 500 chars:')
    print(content[-500:])

if content != original:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'[OK] Updated ({len(original)} -> {len(content)} chars)')
else:
    print('[SKIP] No changes')

print('Done')
