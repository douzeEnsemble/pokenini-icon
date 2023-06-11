from module.Entity.Config.Config import Config
from module.Service.SplitSpriteService import SplitSpriteService
from module.Service.NumberService import NumberService
from module.Service.CleanIconService import CleanIconService
from module.Service.RenameIconService import RenameIconService
from module.Service.NameFromNumberService import NameFromNumberService

class SpriteToIconService:

    def __init__(
        self, 
        configFile, 
        nameFromNumberService: NameFromNumberService,
    ):
        self.config = Config(configFile)
        self.splitSpritesService = SplitSpriteService('config.test.ini')
        self.numberService = NumberService('config.test.ini')
        self.cleanIconService = CleanIconService('config.test.ini')
        self.renameIconService = RenameIconService('config.test.ini')
        self.nameFromNumberService = nameFromNumberService

    def transform(self, spriteFile, targetDir) -> bool:
        numberFile, iconFile = self.splitSpritesService.split(
            spriteFile,
            self.__dir().split_sprite_dir
        )

        number = self.numberService.process(numberFile, self.__dir().number_dir)
        name = self.nameFromNumberService.get(number)

        if '' == name:
            return False

        cleanedIconFile = self.cleanIconService.clean(iconFile, self.__dir().clean_icon_dir)
        self.renameIconService.rename(cleanedIconFile, name, self.__dir().final_base_dir+'/'+targetDir)

        return True

    def __dir(self):
        return self.config.directories