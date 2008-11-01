module MultiCurrency
  class ConvertibleCurrency
    include Comparable
    include ActionView::Helpers::NumberHelper
  
    attr_reader :base_value, :currency
  
    def initialize(value, currency = nil, base_year = Time.now.year)
      @currency = currency
      @year = base_year || Time.now.year
      @@rates_cache = {}
  
      case value
      when String
        @base_value = value.gsub(/\D(\d{3})/, '\1').sub(/\D(\d{1,2})$/, '.\1').to_f
      else
        @base_value = value.to_f
      end
    end
  
    # ========================
    # = General Calculations =
    # ========================
    def +(other)
      ConvertibleCurrency.new(@base_value + other.to_currency(@currency).base_value, @currency || other.currency)
    end
  
    def -(other)
      ConvertibleCurrency.new(@base_value - other.to_currency(@currency).base_value, @currency || other.currency)
    end
  
    def /(other)
      ConvertibleCurrency.new(@base_value / other.to_currency(@currency).base_value, @currency || other.currency)
    end
  
    def *(other)
      ConvertibleCurrency.new(@base_value * other.to_currency(@currency).base_value, @currency || other.currency)
    end
  
    def ==(other)
      @base_value == other.to_currency.base_value
    end
  
    def ===(other)
      @base_value == other.to_currency(@currency).base_value
    end
  
    def <=>(other)
      @base_value <=> other.to_currency(@currency).base_value
    end
  
    # ===============
    # = Conversions =
    # ===============  
    def to_i
      @base_value.round
    end
  
    def to_f
      @base_value
    end
  
    def to_s(unit = true)
      output_currency = MultiCurrency.output_currency || @currency
      number = number_with_delimiter(self.in(output_currency).base_value.round)
  
      if output_currency && unit
        number + " #{output_currency}"
      else
        number
      end
    end
  
    def to_currency(currency = nil, base_year = nil)
      @currency = currency
      @year = base_year
  
      self.in(currency)
    end
  
    def in(currency)
      # If no currency have been given at all or we don't need to convert just return the current object
      return self if currency.blank? || @currency == currency
      
      # If this is an anonymous "0", we can simply set the currency
      if (@base_value == 0) && !@currency
        @currency = currency 
        return self
      end
      
      # If we don't know the currency of the old value, we can't convert it
      raise ConversionOfAnonymousCurrency,
        "Can't convert anonymous currency into #{currency}" unless @currency
  
      # Find exchange rate for old currency -> new currency
      begin
        rate = ExchangeRate.find_rate(@currency, currency, @year) 
      rescue ActiveRecord::RecordNotFound, NoMethodError
        raise ExchangeRateUnavailable, 
          "Can't find exchange rate for conversion from #{@currency} into #{currency} for year #{@year}"
      end
  
      ConvertibleCurrency.new(@base_value * rate, currency, @year)
    end
  end
end
