import sys
import os

from module.Input.FileInput import FileInput
from module.Input.SpritesOutput import SpritesOutput
from module.Input.AreaInput import AreaInput
from module.Service.CropImageService import CropImageService
from module.Service.CropSpriteService import CropSpriteService
from module.Service.SplitSpriteService import SplitSpriteService
from module.Service.NumberService import NumberService
from module.Service.CleanIconService import CleanIconService
from module.Service.RenameIconService import RenameIconService
from module.Service.NameFromNumberService import NameFromNumberService
from module.Service.SpriteToIconService import SpriteToIconService

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
splitSpriteDir = 'temp/sprites-split'
numberDir = 'temp/number'
cleanIconDir = 'temp/clean-icon'
finalDir = 'temp/final/'+sprites.dir

cropImageService = CropImageService('config.ini')
cropImageService.crop(spriteFile, area, croppedImage)

print(f'Base image has been cropped')

cropImageService = CropSpriteService('config.ini') 
cropImageService.crop(croppedImage, croppedSpriteDir)

print(f'All sprites has been cropped')

nameFromNumberService = NameFromNumberService('config.ini')
nameFromNumberService.load(pokemonsListFile)

spriteToIconService = SpriteToIconService('config.ini', nameFromNumberService)

for rootDir, curDir, files in os.walk(croppedSpriteDir):
    total = len(files)
    i = 0
    for file in files:
        isDone = spriteToIconService.transform(croppedSpriteDir+'/'+file, sprites.dir)

        if isDone:
            print(f'{i}/{total}')
            i += 1
