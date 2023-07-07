from PIL import Image
from pathlib import Path

from module.Entity.Config.Config import Config

class ToWebpService:

    def __init__(self, configFile):
        self.config = Config(configFile)

    def convert(self, source):
        path = Path(source)
        destination = path.with_suffix('.webp')
        image = Image.open(source)
        image.save(destination, format='webp', lossless=True, method=6, quality=100)