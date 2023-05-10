import sys

from module.Input.SpriteFileInput import SpriteFileInput
from module.Input.SpritesOutput import SpritesOutput
from module.Input.AreaInput import AreaInput
from module.Service.CropSpritesService import CropSpritesService

# Get args
try:
    spriteFile = sys.argv[1]
    SpriteFileInput.check(spriteFile)

    sprites = SpritesOutput.get(sys.argv[2])

    area = AreaInput.get(sys.argv[3])
except Exception as inst:
    print(inst)
    exit()

print(f'Cut will be for an area of {area.columns}x{area.rows} sprites'
      + f' from {spriteFile} into {sprites.dir}/{sprites.origin} dir/file')

cropSpritesService = CropSpritesService('config.ini')
cropSpritesService.crop(spriteFile, area, 'temp/sprites.png')