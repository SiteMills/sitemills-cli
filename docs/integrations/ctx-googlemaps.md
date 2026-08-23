# Google Maps & Places API

The backend runtime exposes `ctx.googlemaps` so handlers can perform geocoding, reverse geocoding, place lookups, and retrieve the API key.

## Key Configuration

To use Google Maps, projects can either:
1. **Use the platform's default API key**: By calling `await ctx.googlemaps.getApiKey()` from a backend handler, client websites can fetch and use the platform's Google Maps key internally.
2. **Configure a project-specific API key**: Add a project secret in dashboard settings with the variable name `GOOGLE_MAPS_API_KEY`. If configured, `ctx.googlemaps` will automatically resolve this key instead of the platform default.

---

## Methods

### 0) Get Resolved API Key

```typescript
const apiKey = await ctx.googlemaps.getApiKey();
```

Returns the active Google Maps API key (the project-scoped key if defined, or the platform's default key as a fallback). Useful for backend handlers that need to return the key to the frontend dynamically.

---

## Methods

### 1) Geocoding (Address to Coordinates)

```typescript
const result = await ctx.googlemaps.geocode({
    address: '1600 Amphitheatre Parkway, Mountain View, CA'
});
```

**Parameters:**
- `address` (string): The street address to geocode.

**Success Response (Standard Google Geocoding JSON):**
```typescript
{
  status: 'OK',
  results: [
    {
      formatted_address: '1600 Amphitheatre Pkwy, Mountain View, CA 94043, USA',
      geometry: {
        location: {
          lat: 37.4223878,
          lng: -122.0841814
        },
        location_type: 'ROOFTOP',
        viewport: { ... }
      },
      place_id: 'ChIJ2eUgeAK6j4ARbn5u_wvk0qU',
      types: [ 'street_address' ],
      address_components: [ ... ]
    }
  ]
}
```

### 2) Reverse Geocoding (Coordinates to Address)

```typescript
const result = await ctx.googlemaps.reverseGeocode({
    lat: 37.4223878,
    lng: -122.0841814
});
```

**Parameters:**
- `lat` (number): Latitude.
- `lng` (number): Longitude.

**Response:** Standard Google Geocoding JSON containing address results.

### 3) Place Autocomplete

Server-side address autocomplete predictions.

```typescript
const result = await ctx.googlemaps.placeAutocomplete({
    input: '1600 Amphithe',
    types: ['address'] // optional, e.g. ['address'] or ['establishment']
});
```

**Parameters:**
- `input` (string): The text term to search for.
- `types` (string | string[], optional): Restricts results to specific place types.

**Success Response:**
```typescript
{
  status: 'OK',
  predictions: [
    {
      description: '1600 Amphitheatre Parkway, Mountain View, CA, USA',
      matched_substrings: [ ... ],
      place_id: 'ChIJ2eUgeAK6j4ARbn5u_wvk0qU',
      structured_formatting: { ... },
      types: [ 'street_address', 'geocode' ]
    }
  ]
}
```

### 4) Get Place Details

Retrieves details (coordinates, address, phone number, website, rating) for a specific `placeId`.

```typescript
const result = await ctx.googlemaps.getPlaceDetails({
    placeId: 'ChIJ2eUgeAK6j4ARbn5u_wvk0qU'
});
```

**Parameters:**
- `placeId` (string): The Google Place ID (returned from autocomplete or geocoding).

---

## Frontend Integration (Client Script Injection)

To load Google Maps on the client side (in your Preact views) for rendering maps or using places autocomplete:

### 1) Expose a backend route to load the API Key
Create a backend handler in `server/handlers.ts` to return the API key safely (or use a dynamic script loader directly):

```typescript
// server/handlers.ts
export async function getGoogleMapsConfig(ctx) {
    // Get the key dynamically (handles platform fallback automatically)
    const apiKey = await ctx.googlemaps.getApiKey();
    return { apiKey };
}
```

### 2) Dynamic script loader (Preact Hook)
Implement a utility in your views to load the SDK script dynamically on mount:

```typescript
// public/views/home-view.tsx
import { useEffect, useRef, useState } from 'https://esm.sh/preact@10.23.1/hooks';

export function LocationMapComponent() {
  const mapRef = useRef<HTMLDivElement>(null);
  const [sdkLoaded, setSdkLoaded] = useState(false);

  useEffect(() => {
    // 1. Fetch key from backend
    fetch('/api/googlemaps-config')
      .then(res => res.json())
      .then(config => {
        if (!config.apiKey) {
            console.error('Google Maps API key not configured.');
            return;
        }
        
        // 2. Inject script dynamically
        if (window.google) {
          setSdkLoaded(true);
          return;
        }
        
        const script = document.createElement('script');
        script.src = `https://maps.googleapis.com/maps/api/js?key=${config.apiKey}&libraries=places`;
        script.async = true;
        script.defer = true;
        script.onload = () => setSdkLoaded(true);
        document.head.appendChild(script);
      });
  }, []);

  useEffect(() => {
    if (!sdkLoaded || !mapRef.current) return;

    // 3. Render map with location pins
    const position = { lat: 37.4223878, lng: -122.0841814 };
    const map = new google.maps.Map(mapRef.current, {
      center: position,
      zoom: 15
    });

    new google.maps.Marker({
      position,
      map,
      title: 'Googleplex'
    });
  }, [sdkLoaded]);

  return <div ref={mapRef} style={{ width: '100%', height: '400px', borderRadius: '8px' }} />;
}
```
