from wand.image import Image
from module.Entity.Config.Config import Config

class CropImageService:

    def __init__(self, configFile):
        self.config = Config(configFile)

    def crop(self, imageFile, area, outputFile = 'temp/image.png'):
        with Image(filename=imageFile) as original:
            with original.clone() as copy:
                cropWidth = self.config.spriteFull.width * area.columns
                cropHeight = self.config.spriteFull.height * area.rows

                copy.crop(
                    self.config.image.paddingLeft,
                    self.config.image.paddingTop,
                    width=cropWidth, 
                    height=cropHeight
                )
                copy.save(filename=outputFile)