#!/bin/sh

title=$((curl -s "https://api.themoviedb.org/3/movie/top_rated?api_key=$TMDB_API_KEY&language=en-US&page=1" | jq -r .results[].title) | dmenu -p "Enter Name of Movie/Series:" ) || exit 1
encoded_title=$(echo "$title" | jq -sR @uri)

response=$(curl -s "https://api.themoviedb.org/3/search/multi?api_key=$TMDB_API_KEY&query=$encoded_title&language=en-US") || exit 1
[ "$(echo "$response" | jq '.total_results')" -eq 0 ] && exit 1

selected_item=$(echo "$response" | jq -r '.results[] | "\(.title // .name) (\(.release_date // .first_air_date)) | ID: \(.id) | Type: \(.media_type)"' | dmenu -p "Odaberite film ili seriju:") || exit 1
media_id=$(echo "$selected_item" | awk -F "ID: " '{print $2}' | awk '{print $1}')
media_type=$(echo "$selected_item" | awk -F "Type: " '{print $2}' | sed 's/tv/show/')

media_details=$(curl -s "https://api.themoviedb.org/3/$([ "$media_type" = "movie" ] && echo "movie" || echo "tv")/$media_id?api_key=$TMDB_API_KEY&language=en-US") || exit 1
title_output=$(echo "$media_details" | jq -r '.title // .name')
year=$(echo "$media_details" | jq -r '.release_date // .first_air_date' | cut -d'-' -f1)

[ "$media_type" == "show" ] && {
  season_number=$(seq 1 $(echo "$media_details" | jq -r '.number_of_seasons') | xargs -I {} echo "Season {}" | dmenu -p "Choose season:" -l 20 | awk '{print $2}') || exit 1
  episode_number=$(seq 1 $(curl -s "https://api.themoviedb.org/3/tv/$media_id/season/$season_number?api_key=$TMDB_API_KEY&language=en-US" | jq -r '.episodes | length') | xargs -I {} echo "Episode {}" | dmenu -p "Choose episode:" -l 20 | awk '{print $2}') || exit 1
}

json_data=$(jq -n --arg title "$title_output" --argjson year "$year" --arg media_id "$media_id" --arg media_type "$media_type" --arg season "$season_number" --arg episode "$episode_number" '{title: $title, releaseYear: $year, tmdbId: $media_id, imdbId: "tt0137523", type: $media_type, season: $season, episode: $episode}')

url="https://api.whvx.net/search?query=$(echo -n "$json_data" | jq -sRr @uri)&provider=orion&token=$TOKEN"

response=$(curl -s "$url" --compressed -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:134.0) Gecko/20100101 Firefox/134.0' -H 'Origin: https://www.vidbinge.com' | jq -r '.url' | jq -sR @uri | xargs -I {} curl "https://api.whvx.net/source?resourceId={}&provider=orion" -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:134.0) Gecko/20100101 Firefox/134.0' -H 'Origin: https://www.vidbinge.com' -s)

subtitles_url="https://subs.whvx.net/search?id=$media_id"
[ -n "$season_number" ] && [ -n "$episode_number" ] && subtitles_url+="&season=$season_number&episode=$episode_number"

subtitle_url=$(curl -s "$subtitles_url" | jq -r '.[] | "\(.languageName) (\(.language)) - \(.url)"' | dmenu -p "Select subtitles:" | awk '{print $NF}' | head -n 1)

[ -n "$subtitle_url" ] && mpv "$(echo $response | jq -r '.stream[0].playlist')" --sub-file="$subtitle_url"
