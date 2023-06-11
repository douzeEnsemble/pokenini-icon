import os

from pathlib import Path

from wand.image import Image

from module.Entity.Config.Config import Config

class BleachService:

    def __init__(self, configFile):
        self.config = Config(configFile)

    def bleach(self, numberFile, targetFile):
        with Image(filename=numberFile) as img:
            img.opaque_paint(
                target=self.__getFirstPixelColor(numberFile), 
                fill='white', 
                fuzz=0.10
            )
            img.opaque_paint(
                target='#112037', 
                fill='black', 
                fuzz=0.10
            )

            img.save(filename=targetFile)

    def __getFirstPixelColor(self, numberFile):
        with Image(filename=numberFile) as img:
            return img[0, 0]