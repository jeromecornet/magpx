require 'nokogiri'
require 'json'
require "loc"

module MagGPX
  module GPX
    STEPS_M = 10 # Generate at most 1 point per 10 m
    SLICE = 50
    extend self

    def mapbox_route(filename)
      tp = trackpoints(filename)
      last_point = nil
      simplified_route = tp.each_slice(50).flat_map do |trackpoints|
        trackpoints.map do |tp|
          lon = tp[:lng]
          lat = tp[:lat]
          point = Loc::Location[lat, lon]
          next unless (last_point.nil? || point.distance_to(last_point) > STEPS_M)

          last_point = point
          { longitude: lon, latitude: lat, elevation: tp[:elevation] }
        end
      end

      index = 0
      route_with_steps = simplified_route.compact.each_slice(SLICE).map do |trackpoints|
        matching = Mapbox::MapMatching.map_matching(trackpoints, "cycling",
                                                    {
                                                      annotations: ["duration", "distance", "speed"],
                                                      steps: true,
                                                      geometries: "polyline6",
                                                      overview: "full",
                                                      tidy: true,
                                                      waypoints: [0, trackpoints.length - 1]
                                                    })
        if Configuration.debug?
          File.open("route-#{index.to_s.rjust(4, "0")}.json", 'w') do |file|
            JSON.dump(matching.first, file)
          end
        end

        index += 1
        puts "Processed #{index} file"
        matching
      end
      { name: name(filename), trackpoints: simplified_route, legs: route_with_steps }
    end

    def trackpoints(filename)
      doc = Nokogiri::XML(open(filename))
      trackpoints = doc.xpath('//gpx:trkpt', gpx: "http://www.topografix.com/GPX/1/1")
      trackpoints.map do |trkpt|
        {
          lat: trkpt.xpath('@lat').to_s.to_f,
          lng: trkpt.xpath('@lon').to_s.to_f,
          elevation: trkpt.xpath('gpx:ele[text()]', gpx: "http://www.topografix.com/GPX/1/1").text.to_f
        }
      end
    end

    def name(filename)
      doc = Nokogiri::XML(open(filename))
      doc.xpath('//gpx:trk/gpx:name', gpx: "http://www.topografix.com/GPX/1/1").text
    end

  end
end