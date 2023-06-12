import sys
import os

from module.Entity.Config.Config import Config
from module.Input.FileInput import FileInput
from module.Input.SpritesOutput import SpritesOutput
from module.Input.AreaInput import AreaInput
from module.Service.CropImageService import CropImageService
from module.Service.CropSpriteService import CropSpriteService
from module.Service.NameFromNumberService import NameFromNumberService
from module.Service.SpriteToIconService import SpriteToIconService
from module.Service.SpritesToIconsService import SpritesToIconsService
from module.Service.CleanTempFilesService import CleanTempFilesService
from module.Service.CompareDirToListService import CompareDirToListService

configFile = 'config.ini'
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

config = Config(configFile)
print(f'Cut will be for an area of {area.columns}x{area.rows} sprites'
      + f' from {spriteFile} into {sprites.dir}/{sprites.origin} dir/file')

croppedImage = config.files.cropped_image
croppedSpriteDir = config.directories.cropped_sprite_dir

cropImageService = CropImageService(configFile)
cropImageService.crop(spriteFile, area, croppedImage)

print(f'Base image has been cropped')

cropImageService = CropSpriteService(configFile) 
cropImageService.crop(croppedImage, croppedSpriteDir)

print(f'All sprites has been cropped')

nameFromNumberService = NameFromNumberService(configFile)
nameFromNumberService.load(pokemonsListFile)

spriteToIconService = SpriteToIconService(configFile, nameFromNumberService)

spritesToIconsService = SpritesToIconsService(configFile, spriteToIconService)

spritesToIconsService.cut(
    croppedSpriteDir,
    sprites.dir
)

CleanTempFilesService(configFile).clean()

compareDirToListService = CompareDirToListService(configFile) 
missingIcons = compareDirToListService.compare(
    config.directories.final_base_dir+'/'+sprites.dir,
    pokemonsListFile,
)

print(missingIcons)