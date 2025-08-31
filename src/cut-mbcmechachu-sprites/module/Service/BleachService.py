from wand.image import Image

from module.Entity.Config.Config import Config

class BleachService:

    def __init__(self, configFile):
        self.config = Config(configFile)

    def bleach(self, numberFile, targetFile):
        with Image(filename=numberFile) as img:
            # Replace the background color with white
            img.opaque_paint(
                target=self.__getFirstPixelColor(numberFile), 
                fill='white', 
                fuzz=0.10
            )

            # Replace some black-ish with black
            img.opaque_paint(
                target='#373737', 
                fill='black', 
                fuzz=0.10
            )
            # Replace another black-ish with black
            img.opaque_paint(
                target='#3A3737', 
                fill='black', 
                fuzz=0.10
            )
            # Replace some white-ish with black            
            img.opaque_paint(
                target='#f4f4f4', 
                fill='black', 
                fuzz=0.10
            )

            img.save(filename=targetFile)

    def __getFirstPixelColor(self, numberFile):
        with Image(filename=numberFile) as img:
            return img[0, 0]