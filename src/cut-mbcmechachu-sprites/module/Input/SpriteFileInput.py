from module.Entity.Sprite.RegularSprite import RegularSprite
from module.Entity.Sprite.ShinySprite import ShinySprite

class SpriteFileInput:

    @staticmethod
    def get(type: str):
        match type.upper():
            case 'R':
                return RegularSprite()
            case 'S':
                return ShinySprite()
            case _:
                raise Exception('R or S you must choose, "'+type+'" given')