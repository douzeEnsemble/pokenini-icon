from module.Entity.Sprite.RegularSprite import RegularSprite
from module.Entity.Sprite.ShinySprite import ShinySprite

class SpritesOutput:

    @staticmethod
    def get(type: str):
        match type.upper():
            case 'R':
                return RegularSprite()
            case 'S':
                return ShinySprite()
            case _:
                raise Exception('R (for regular) or S (for shiny) you must choose, "'+type+'" given')