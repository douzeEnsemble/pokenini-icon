import sys
import os

from module.Input.FileInput import FileInput
from module.Input.SpritesOutput import SpritesOutput
from module.Input.AreaInput import AreaInput
from module.Service.CropImageService import CropImageService
from module.Service.CropSpriteService import CropSpriteService
from module.Service.NameFromNumberService import NameFromNumberService
from module.Service.SpriteToIconService import SpriteToIconService
from module.Service.SpritesToIconsService import SpritesToIconsService
from module.Service.CleanTempFilesService import CleanTempFilesService

# Get args
try:
    spriteFile = sys.argv[1]
    FileInput.check(spriteFile)

    sprites = SpritesOutput.get(sys.argv[2])

    area = AreaInput.get(sys.argv[3])

    pokemonsListFile = sys.argv[4]
    FileInput.check(spriteFile)

except Exception as inst:
    print(inst)
    exit()

print(f'Cut will be for an area of {area.columns}x{area.rows} sprites'
      + f' from {spriteFile} into {sprites.dir}/{sprites.origin} dir/file')

croppedImage = 'temp/image.png'
croppedSpriteDir = 'temp/sprites'

cropImageService = CropImageService('config.ini')
cropImageService.crop(spriteFile, area, croppedImage)

print(f'Base image has been cropped')

cropImageService = CropSpriteService('config.ini') 
cropImageService.crop(croppedImage, croppedSpriteDir)

print(f'All sprites has been cropped')

nameFromNumberService = NameFromNumberService('config.ini')
nameFromNumberService.load(pokemonsListFile)

spriteToIconService = SpriteToIconService('config.ini', nameFromNumberService)

spritesToIconsService = SpritesToIconsService('config.ini', spriteToIconService)

spritesToIconsService.cut(
    croppedSpriteDir,
    sprites.dir
)

CleanTempFilesService('config.ini').clean()