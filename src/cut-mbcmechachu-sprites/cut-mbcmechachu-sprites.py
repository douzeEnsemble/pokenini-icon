import sys
import os

from module.Entity.Config.Config import Config
from module.Entity.Config.TypedConfig import TypedConfig
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
    type = sys.argv[1]

    typedConfig = TypedConfig(configFile, type)

    spriteFile = typedConfig.resource_file
    outputDir = typedConfig.output_dir

    area = AreaInput.get(sys.argv[2])

    pokemonsListFile = typedConfig.list_file
except Exception as inst:
    print(inst)
    exit()

config = Config(configFile)

CleanTempFilesService(configFile).clean()

print(f'Cut will be for an area of {area.columns}x{area.rows} sprites'
      + f' from {type} into {outputDir} dir')

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
    type
)

CleanTempFilesService(configFile).clean()

compareDirToListService = CompareDirToListService(configFile) 
try:
    missingIcons = compareDirToListService.compare(
        config.directories.final_base_dir+'/'+outputDir,
        pokemonsListFile,
    )
except Exception as inst:
    print("No icons has been cut")
    exit()

print(missingIcons)