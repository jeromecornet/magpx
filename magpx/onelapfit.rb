require 'json'
require "loc"
require "fast_polylines"
require 'net/http'

module MagGPX
  module Onelapfit
    ROUTE_SAVE_ENDPOINT = "http://rfs-fitness.rfsvr.com/api/navigation/app/navigation/save"
    extend self

    def convert_mapbox_steps(legs, trackpoints: [], name: "Imported route")
      total_distance = 0
      total_time = 0
      path_points = []
      navigation_steps = []

      fill_trackpoint = if trackpoints.blank?
                          trackpoints = []
                          true
                        else
                          trackpoints = trackpoints.compact
                          false
                        end

      simplified_steps = []
      legs.each do |leg|
        if leg.is_a?(Array) && leg.count == 2
          leg = leg.first
        end

        next if leg["code"] == "NoMatch"

        summary = leg["matchings"].first
        waypoint = leg["tracepoints"].first
        path_points << {
          "name": waypoint["name"],
          "lng": waypoint["location"].first,
          "distance": summary["distance"],
          "duration": summary["duration"],
          "lat": waypoint["location"].last,
          "intersectionsSize": 14
        }
        total_time += summary["duration"]
        total_distance += summary["distance"]

        summary["legs"].first["steps"].each do |step|
          if fill_trackpoint
            trackpoints << { latitude: step["maneuver"]["location"].last, longitude: step["maneuver"]["location"].first, elevation: 0 }
          end

          simplified_steps << step["maneuver"]["location"].reverse # lat/lng are reversed
          olstep = {
            dest_type: 1,
            duration: step["duration"].round(1),
            distance: step["distance"].round(1),
            name: step["name"],
            path: step["geometry"],
            instruction: step["maneuver"]["instruction"]
          }
          maneuver = case step["maneuver"]["type"]
                     when "turn", "fork", "roundabout"
                       case step["maneuver"]["modifier"]
                       when "straight"
                         {
                           direction: 0,
                           turn_type: "直行"
                         }
                       when "left"
                         {
                           direction: 1,
                           turn_type: "左转"
                         }
                       when "slight left"
                         {
                           direction: 2,
                           turn_type: "左前"
                         }
                       when "right"
                         {
                           direction: 3,
                           turn_type: "右转"
                         }
                       when "slight right"
                         {
                           direction: 4,
                           turn_type: "右前"
                         }
                       when "sharp left"
                         {
                           direction: 6,
                           turn_type: "左后"
                         }
                       when "sharp right"
                         {
                           direction: 7,
                           turn_type: "右后"
                         }
                       when "uturn"
                         {
                           direction: 8,
                           turn_type: "右转"
                         }
                       else
                         puts "Unknown maneuver modifier: #{step["maneuver"]["modifier"]}"
                       end
                     when "depart", "arrive", "continue", "notification", "end of road", "new name"
                       {
                         direction: 0,
                         turn_type: "直行"
                       }
                     else
                       puts "Unknown maneuver type: #{step["maneuver"]["type"]}"
                     end
          navigation_steps << olstep.merge(maneuver) if maneuver.present?
        end
      end

      highest_slope = 0
      total_climb = 0
      altitude_legs = trackpoints.each_slice(GPX::SLICE).map do |leg_tp|
        climb = 0
        previous_pt = nil
        leg_distance = 0
        leg_tp.each do |tp|
          next if tp[:latitude].nil? || tp[:longitude].nil?
          if previous_pt.nil?
            previous_pt = tp
          else
            distance = Loc::Location[previous_pt[:latitude], previous_pt[:longitude]].distance_to(Loc::Location[tp[:latitude], tp[:longitude]])
            leg_distance += distance
            if tp[:elevation] > previous_pt[:elevation]
              gain = tp[:elevation] - previous_pt[:elevation]
              climb += gain
              slope = gain / distance
              highest_slope = slope if slope > highest_slope
            end
            previous_pt = tp
          end
        end
        total_climb += climb

        {
          "climb": climb.to_i,
          "altitude_info": leg_tp.map { |tp| { lat: tp[:lat], lng: tp[:lng], elevation: tp[:elevation].to_i } },
          "altitude": leg_tp.first[:elevation].to_i
        }
      end

      data = {
        name: name,
        size: 128,
        distance: total_distance,
        time: total_time,
        path_point: path_points,
        path_steps: navigation_steps,
        import_path: navigation_steps.map do |step|
          coords = FastPolylines.decode(step[:path], 6)
          step.merge(path: coords.map { |lng, lat| { lng: lng, lat: lat } })
        end,
        altitude: trackpoints.first[:elevation].to_i,
        altitude_info: {
          slope: highest_slope,
          steps_info: altitude_legs
        },
        geometry: FastPolylines.encode(simplified_steps, 6),
        climb: total_climb.to_i,
      }

      if Configuration.debug?
        File.open("onelap-route.json", 'w') do |file|
          JSON.dump(data, file)
        end
      end
      data
    end

    def save_route(route)
      response = Net::HTTP.post(URI(ROUTE_SAVE_ENDPOINT),
                                JSON.dump(route),
                                Configuration.request_headers({ ShowId: "1fafed1b-77aa-4e75-8fb2-a31a99285731" }))

      if Configuration.debug?
        File.open("onelap-response.json", 'w') do |file|
          JSON.dump(response.body, file)
        end
      end

      if JSON.parse(response.body)["code"] == 200
        puts "Route saved"
      else
        raise StandardError, "Error while saving route\n#{response.body}"
      end
    end
  end
end