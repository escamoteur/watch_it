import 'dart:async';
import 'dart:convert';

import 'package:flutter_command/flutter_command.dart';
import 'package:http/http.dart' as http;

import 'json/weather_in_cities.dart';

class WeatherManager {
  late Command<String?, List<WeatherEntry>> updateWeatherCommand;
  late Command<bool, bool> setExecutionStateCommand;
  late Command<String, String> textChangedCommand;

  WeatherManager() {
    // Command expects a bool value when executed and sets it as its own value
    setExecutionStateCommand = Command.createSync<bool, bool>((b) => b, true);

    // We pass the result of switchChangedCommand as restrictions to the upDateWeatherCommand
    updateWeatherCommand = Command.createAsync<String?, List<WeatherEntry>>(
      update, // Wrapped function
      [], // Initial value
      restriction: setExecutionStateCommand,
    );

    // Will be called on every change of the search-field
    textChangedCommand = Command.createSync((s) => s, '');

    // handler for results
    // make sure we start processing only if the user make a short pause typing
    textChangedCommand.debounce(Duration(milliseconds: 500)).listen(
      (filterText, _) {
        // I could omit he execute because Command is a callable
        // class  but here it makes the intention clearer
        updateWeatherCommand.execute(filterText);
      },
    );

    updateWeatherCommand.thrownExceptions.listen((ex, _) => print(ex.toString()));

    // Update data on start-up
    updateWeatherCommand.execute();
  }

  // Async function that queries the REST API and converts the result into the form our ListViewBuilder can consume
  Future<List<WeatherEntry>> update(String? filtertext) {
    const url =
        "https://api.openweathermap.org/data/2.5/box/city?bbox=12,32,15,37,10&appid=27ac337102cc4931c24ba0b50aca6bbd";

    var httpStream = http.get(Uri.parse(url)).timeout(const Duration(seconds: 5)).asStream();

    return httpStream.where((data) => data.statusCode == 200) // only continue if valid response
        .map(
      (data) {
        // convert JSON result into a List of WeatherEntries
        return WeatherInCities.fromJson(json.decode(data.body) as Map<String, dynamic>)
            .cities // we are only interested in the Cities part of the response
            .where((weatherInCity) =>
                filtertext == null ||
                filtertext.isEmpty || // if filtertext is null or empty we return all returned entries
                weatherInCity.name
                    .toUpperCase()
                    .startsWith(filtertext.toUpperCase())) // otherwise only matching entries
            .map((weatherInCity) => WeatherEntry(weatherInCity)) // Convert City object to WeatherEntry
            .toList(); // aggregate entries to a List
      },
    ).first; // Return result as Future
  }
}

class WeatherEntry {
  late String cityName;
  String? iconURL;
  late double wind;
  late double rain;
  late double temperature;
  String? description;

  WeatherEntry(City city) {
    this.cityName = city.name;
    this.iconURL = city.weather[0].icon != null ? "https://openweathermap.org/img/w/${city.weather[0].icon}.png" : null;
    this.description = city.weather[0].description;
    this.wind = city.wind.speed.toDouble();
    this.rain = city.rain;
    this.temperature = city.main.temp;
  }
}
