from wand.image import Image
from module.Entity.Config.Config import Config

class CropSpritesService:

    def __init__(self, configFile = 'config.ini'):
        self.config = Config(configFile)

    def crop(self, spriteFile, area, outputFile = 'temp/sprites.png'):
        with Image(filename=spriteFile) as original:
            with original.clone() as copy:
                cropWidth = self.config.spriteFull.width * area.columns
                cropHeight = self.config.spriteFull.height * area.rows

                copy.crop(
                    self.config.sprites.paddingLeft,
                    self.config.sprites.paddingTop,
                    width=cropWidth, 
                    height=cropHeight
                )
                copy.save(filename=outputFile)