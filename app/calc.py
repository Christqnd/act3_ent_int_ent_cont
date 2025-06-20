import app
import math


class InvalidPermissions(Exception):
    pass


class Calculator:
    
    def add(self, x, y):
        self.check_types(x, y)
        return x + y

    def substract(self, x, y):
        self.check_types(x, y)
        return x - y

    def multiply(self, x, y):
        if not app.util.validate_permissions(f"{x} * {y}", "user1"):
            raise InvalidPermissions('User has no permissions')
        self.check_types(x, y)
        return x * y

    def divide(self, x, y):
        self.check_types(x, y)
        if y == 0:
            raise TypeError("Division by zero is not possible")
        return x / y

    def power(self, x, y):
        self.check_types(x, y)
        return x ** y

    def sqrt(self, x):
        self.check_types(x)
        if x < 0:
            raise TypeError("Cannot compute square root of negative number")
        return math.sqrt(x)
    
    def log10(self, x):
        self.check_types(x)
        if x <= 0:
            raise TypeError("Cannot compute logarithm of zero or negative number")
        return math.log10(x)

    def check_types(self, x, y=None):
        if not isinstance(x, (int, float)):
            raise TypeError("Parameter must be a number")
        if y is not None and not isinstance(y, (int, float)):
            raise TypeError("Second parameter must be a number")



if __name__ == "__main__":  # pragma: no cover
    calc = Calculator()
    result = calc.add(2, 2)
    print(result)
