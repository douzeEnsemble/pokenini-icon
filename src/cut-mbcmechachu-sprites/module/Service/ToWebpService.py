# from PIL import Image
from wand.image import Image
from pathlib import Path

from module.Entity.Config.Config import Config

class ToWebpService:

    def __init__(self, configFile):
        self.config = Config(configFile)

    def convert(self, source):
        with Image(filename = source) as img:
            path = Path(source)

            destination = path.with_suffix('.webp')

            # Change format in python using format property
            img.format = 'webp'
        
            # Save final image
            img.save(filename = destination)
  
        # destination = source.with_suffix('.webp')
        # image = Image.open(source)
        # image.save(destination, format='webp')