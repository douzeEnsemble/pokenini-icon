import sys
from module.Input.SpriteFileInput import SpriteFileInput
from module.Input.AreaInput import AreaInput

try:
    sprite = SpriteFileInput.get(sys.argv[1])
except Exception as inst:
    print(inst)
    exit()

area = AreaInput.get(sys.argv[2])

print(sys.argv)
print(area.size, sprite.dir, sprite.origin)