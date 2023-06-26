from module.Entity.Config.Config import Config
from module.Service.SplitSpriteService import SplitSpriteService
from module.Service.NumberService import NumberService
from module.Service.CleanIconService import CleanIconService
from module.Service.RenameIconService import RenameIconService
from module.Service.NameFromNumberService import NameFromNumberService
from module.Service.ToWebpService import ToWebpService

class SpriteToIconService:

    def __init__(
        self, 
        configFile, 
        nameFromNumberService: NameFromNumberService,
    ):
        self.config = Config(configFile)
        self.splitSpritesService = SplitSpriteService(configFile)
        self.numberService = NumberService(configFile)
        self.cleanIconService = CleanIconService(configFile)
        self.renameIconService = RenameIconService(configFile)
        self.toWebpService = ToWebpService(configFile)

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

        numberedDir = self.__dir().final_base_dir+'/'+self.config.files.output_numbered_dir_prefix+targetDir
        spritesDir = self.__dir().final_base_dir+'/'+targetDir

        self.renameIconService.rename(cleanedIconFile, number, numberedDir)
        result = self.renameIconService.rename(cleanedIconFile, name, spritesDir)
        
        self.toWebpService.convert(result)

        return True

    def __dir(self):
        return self.config.directories