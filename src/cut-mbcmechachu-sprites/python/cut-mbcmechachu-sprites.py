import sys
import os
from pathlib import Path

from module.Input.ImageFileInput import ImageFileInput
from module.Input.SpritesOutput import SpritesOutput
from module.Input.AreaInput import AreaInput
from module.Service.CropImageService import CropImageService
from module.Service.CropSpriteService import CropSpriteService
from module.Service.SplitSpriteService import SplitSpriteService
from module.Service.NumberService import NumberService

# Get args
try:
    spriteFile = sys.argv[1]
    ImageFileInput.check(spriteFile)

    sprites = SpritesOutput.get(sys.argv[2])

    area = AreaInput.get(sys.argv[3])
except Exception as inst:
    print(inst)
    exit()

print(f'Cut will be for an area of {area.columns}x{area.rows} sprites'
      + f' from {spriteFile} into {sprites.dir}/{sprites.origin} dir/file')

croppedImage = 'temp/image.png'
croppedSpriteDir = 'temp/sprites/'
splitSpriteDir = 'temp/sprites-split/'

cropImageService = CropImageService('config.ini')
cropImageService.crop(spriteFile, area, croppedImage)

cropImageService = CropSpriteService('config.test.ini') 
cropImageService.crop(croppedImage, croppedSpriteDir)

splitSpritesService = SplitSpriteService('config.test.ini')

numberService = NumberService('config.test.ini')

for rootDir, curDir, files in os.walk(croppedSpriteDir):
    for file in files:
        numberFile, iconFile = splitSpritesService.split(
            croppedSpriteDir+file,
            splitSpriteDir
        )

        number = numberService.process(numberFile)

