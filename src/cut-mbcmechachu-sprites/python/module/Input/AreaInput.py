from module.Entity.Area.CompleteArea import CompleteArea
from module.Entity.Area.LineArea import LineArea
from module.Entity.Area.SampleArea import SampleArea
from module.Entity.Area.ThreeColumnsArea import ThreeColumnsArea
from module.Entity.Area.ThreeRowsArea import ThreeRowsArea

class AreaInput:

    @staticmethod
    def get(type: str):
        match type:
            case 'complete':
                return CompleteArea()
            case 'line':
                return LineArea()
            case 'sample':
                return SampleArea()
            case '3cols':
                return ThreeColumnsArea()
            case '3rows':
                return ThreeRowsArea()
            case _:
                return CompleteArea()
